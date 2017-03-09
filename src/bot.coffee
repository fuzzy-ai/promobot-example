# bot.coffee
Botkit = require 'botkit'
FuzzyAI = require 'fuzzy.ai'
agent = require './agent'

# Setup fuzzy.ai client
COUPONS = JSON.parse process.env.COUPONS
AGENT_ID = process.env.FUZZYAI_AGENT
API_ROOT = process.env.FUZZYAI_ROOT || 'https://api.fuzzy.ai'
client = new FuzzyAI({key: process.env.FUZZYAI_KEY, root: API_ROOT})
client.putAgent AGENT_ID, agent, (err) ->
  if err
    console.error "Error updating agent"

# Configure the botkit controller and spawn the bot.
controller = Botkit.facebookbot
  debug: true
  log: true
  receive_via_postback: true
  access_token: process.env.PAGE_TOKEN
  verify_token: process.env.VERIFY_TOKEN
  app_secret: process.env.APP_SECRET
bot = controller.spawn()

# Setup webhooks for operating with Facebook
controller.setupWebserver process.env.PORT || 3000, (err, server) ->
  controller.createWebhookEndpoints server, bot, () ->
    console.log "server started!"

controller.api.thread_settings.greeting("Welcome to PromoBot!")

# Main conversation with questions and branching
promoConvo = (bot, message) ->
  bot.createConversation message, (err, convo) ->
    convo.addMessage({
      text: "I didn't understand that"
      action: 'default'
      }, 'default_action')

    convo.addMessage({
      text: 'What are you waiting for?'
      action: 'completed'
    }, 'user_no_thread')
    convo.addMessage({
      text: "That's great!"
      action: 'tutorial_question'
    },'user_yes_thread')

    convo.addMessage({
      text: 'You should check it out! https://fuzzy.ai/tutorial'
      action: 'api_question'
    }, 'tutorial_no_thread')
    convo.addMessage({
      text: 'Great news!'
      action: 'api_question'
    }, 'tutorial_yes_thread')

    convo.addQuestion('Have you completed our tutorial?', [
        {
          pattern: bot.utterances.no
          callback: (response, convo) ->
            convo.changeTopic 'tutorial_no_thread'
        },
        {
          pattern: bot.utterances.yes
          callback: (response, convo) ->
            convo.changeTopic 'tutorial_yes_thread'
        }
        {
          default: true,
          callback: (response, convo) ->
            convo.changeTopic 'default_action'
        }
      ], {key: 'tutorial'}, 'tutorial_question')

    convo.addQuestion({
      attachment:
        type: 'template'
        payload:
          template_type: 'button'
          text: 'When was your last API call on fuzzy.ai?'
          buttons: [
            {
              type: 'postback'
              title: 'Never'
              payload: 0
            },
            {
              type: 'postback'
              title: 'In the last week'
              payload: 7
            },
            {
              type: 'postback'
              title: "It's been longer"
              payload: 30
            }
          ]
      }, (response, convo) ->
        convo.next()
      , {key: 'lastAPICall'}, 'api_question')

    convo.ask 'Hi! Are you currently a fuzzy.ai user?', [
      {
        pattern: bot.utterances.no
        callback: (response, convo) ->
          console.log response, "RESPONSE"
          convo.changeTopic 'user_no_thread'

      },
      {
        pattern: bot.utterances.yes
        callback: (response, convo) ->
          convo.changeTopic 'user_yes_thread'
      },
      {
        default: true,
        callback: (response, convo) ->
          convo.changeTopic 'default_action'
      }
    ], {'key': 'hasAccount'}

    convo.on 'end', (convo) ->
      if convo.status == 'completed'
        responses = convo.extractResponses()
        inputs = responsesToInputs(responses)

        # Evaluate response
        client.evaluate AGENT_ID, inputs, (err, outputs) ->
          if err
            bot.reply message, "Uh oh, something went wrong."
          else
            if outputs['discount'] > 1
              discount = 5 * Math.ceil(outputs['discount'] / 5)
              code = discountToCode(discount)
              bot.reply message, "Use this coupon code: #{code} for #{discount}% off an upgrade!"
            else
              bot.reply message, "So nice to talk to you!"
      else
        bot.reply message, "Thanks for chatting."

    convo.activate()


# Start the promotion conversation on optin or when the user says "hi"
controller.on 'facebook_optin', promoConvo
controller.hears ['hi', 'hello', 'start'], 'message_received', promoConvo

# Convert responses to numbers
responsesToInputs = (inputs) ->
  if inputs['hasAccount']
    if inputs['hasAccount'].match(bot.utterances.yes)
      inputs['hasAccount'] = 1
    else
      inputs['hasAccount'] = 0
  if inputs['tutorial']
    if inputs['tutorial'].match(bot.utterances.yes)
      inputs['tutorial'] = 1
    else
      inputs['tutorial'] = 0
  if inputs['lastAPICall']
    inputs['lastAPICall'] = parseInt(inputs['lastAPICall'])
  inputs

# Convert API response to Coupon Code
discountToCode = (discount) ->
  COUPONS[discount]
