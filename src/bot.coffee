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
  debug: process.env.NODE_ENV != "production"
  log: true
  receive_via_postback: true
  require_delivery: true
  access_token: process.env.PAGE_TOKEN
  verify_token: process.env.VERIFY_TOKEN
  app_secret: process.env.APP_SECRET
bot = controller.spawn()

# Setup webhooks for operating with Facebook
controller.setupWebserver process.env.PORT || 3000, (err, server) ->
  controller.createWebhookEndpoints server, bot, () ->
    console.log "server started!"

controller.api.thread_settings.greeting("Welcome to PromoBot!")
controller.api.thread_settings.get_started('start')
controller.api.thread_settings.menu([
  {
    type: "postback",
    title: "Start Demo",
    payload: "start"
  },
  {
    type: "web_url",
    title: "View Source",
    url: "https://github.com/fuzzy-ai/promobot-example"
  }
  ])

promoConvo = (bot, message) ->
  bot.startConversation(message, askUser)

# Start the promotion conversation on optin or when the user says "hi"
controller.on 'facebook_optin', promoConvo
controller.hears ['hi', 'hello', 'start'], 'message_received', promoConvo


askUser = (response, convo) ->
  convo.ask 'Hi! Are you currently a fuzzy.ai user?', [
    {
      pattern: bot.utterances.yes
      callback: (response, convo) ->
        convo.say "That's great!"
        askTutorial response, convo
        convo.next()
    },
    {
      pattern: bot.utterances.no
      callback: (response, convo) ->
        convo.say "What are you waiting for?"
        runEvaluation convo
        convo.next()
    },
    {
      default: true
      callback: (response, convo) ->
        convo.repeat()
        convo.next()
    }
  ], {key: 'hasAccount'}

askTutorial = (response, convo) ->
  convo.ask 'Have you completed our tutorial?', [
    {
      pattern: bot.utterances.yes
      callback: (response, convo) ->
        convo.say "Great news!"
        askApiUsage(response, convo)
        convo.next()
    },
    {
      pattern: bot.utterances.no
      callback: (response, convo) ->
        convo.say "You should check it out! https://fuzzy.ai/tutorial"
        askApiUsage(response, convo)
        convo.next()
    },
    {
      default: true
      callback: (response, convo) ->
        convo.repeat()
        convo.next()
    }
  ], {key: 'tutorial'}

askApiUsage = (response, convo) ->
  convo.ask {
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
      runEvaluation(convo)
      convo.next()
    , {key: 'lastAPICall'}

runEvaluation = (convo) ->
  responses = convo.extractResponses()
  inputs = responsesToInputs(responses)

  # Evaluate response
  client.evaluate AGENT_ID, inputs, true, (err, outputs) ->
    if err
      convo.say "Uh oh, something went wrong."
    else
      if outputs['discount'] > 1
        discount = 5 * Math.ceil(outputs['discount'] / 5)
        code = discountToCode(discount)
        convo.say "Use this coupon code: #{code} for #{discount}% off an upgrade!  https://fuzzy.ai/signup?code=#{code}"
        convo.say "I determined that response using a Fuzzy.ai 'evaluate' call with the inputs: #{JSON.stringify inputs}"
        askFeedback(convo, outputs['discount'], outputs.meta.reqID)
      else
        convo.say "So nice to talk to you!"
    convo.next()

askFeedback = (convo, discount, eval_id) ->
  convo.ask 'Will you use the code?', (response, convo) ->
    if response.text.match(bot.utterances.yes)
      metrics = {discount: 100 - discount}
    else if response.text.match(bot.utterances.no)
      metrics = {discount: 0}

    if metrics
      client.feedback eval_id, metrics, (err) ->
        if err
          convo.say "Oh no! Something went wrong."
        else
          convo.say "Thanks for letting us know!"
          convo.say "We provided feedback to the algorithm: #{JSON.stringify metrics}"
        convo.say "You can see my full source code on Github: https://github.com/fuzzy-ai/promobot-example"
    else
      convo.repeat()
    convo.next()

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
