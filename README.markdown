# JIRA Bot

### About


This is just a simple Ruby-based IRC bad which will pull in information from
JIRA and Gerrit.


### Configuration

The bot requires two configuration files `config/bot.yml` and
`config/summer.yml`.

See the respective `.example` files for how to configure them



### Commands

`jirabot` doesn't really have any commands, it will just pick up on a couple of
keywords/tokens:

    +----------------------------------------------------------------------------
    |   token   |             output
    +-----------+----------------------------------------------------------------
    |  cr-1233  |   Fetch the subject and status from change #1233 in Gerrit
    +-----------+----------------------------------------------------------------
    |  svr-238  |   Fetch the assignee and summary for JIRA: SVR-238
    +-----------+----------------------------------------------------------------

