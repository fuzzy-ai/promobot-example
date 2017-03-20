# Fuzzy.ai Promobot

An example Facebook Messenger bot built with [Botkit](https://www.botkit.ai/) to demonstrate integration with [Fuzzy.ai](https://fuzzy.ai/).

## Usage

To try out the bot, add it on Messenger: https://m.me/fuzzy.ai.promobot

Either select 'Start Demo' or just say "hi".

## Development Installation

If you want to run your own instance of the bot, clone this repository and do the following:

1. Run `npm install`
1. Copy `env.example` to `.env` and populate values:
  1. For `PAGE_TOKEN`, `VERIFY_TOKEN` and `APP_SECRET` follow the [Botkit instructions](https://github.com/howdyai/botkit/blob/master/readme-facebook.md#getting-started) for generating these values from Facebook.
  1. Copy your Fuzzy.ai API Key from your [Fuzzy.ai Dashboard](https://fuzzy.ai/) to `FUZZYAI_KEY`.
  1. Create an "Empty" agent and copy the ID to `FUZZYAI_AGENT`.
1. Run the bot via `npm run dev`.
