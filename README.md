# Codeowners Helper

Codeowners Helper is a command-line interface for CODEOWNERS maintenance for teams with lots of repos on GitHub Enterprise.

## Prerequisites

* [Ruby](https://www.ruby-lang.org/en/documentation/installation/) — 2.6 recommended

* <details>
  <summary>GitHub Enterprise
  </summary>

  ### [Setup an OAuth App](https://developer.github.com/apps/building-oauth-apps/creating-an-oauth-app/)

    1. Sign in to GitHub Enterprise
    2. Go to "Settings" > "Developer settings" > "OAuth Apps"
    3. Click "New OAuth App"
    4. Fill in the appropriate fields; they don't require specific values but here's some suggested values

       * Application Name: `Codeowners Helper`
       * Homepage URL: `https://github.com/blakebuthod/codeowners-helper`
       * Authorization callback URL: `https://github.com/blakebuthod/codeowners-helper`

    5. A **client id** and **client secret** will be generated

  ### [Retrieve an OAuth Token](https://developer.github.com/enterprise/2.18/apps/building-oauth-apps/authorizing-oauth-apps/#web-application-flow)

  1. Go to this URL in your browser: `http(s)://[HOSTNAME]/login/oauth/authorize?scope=repo&client_id=[CLIENT_ID]`
  2. It will redirect you (based on the value used for "Authorization callback URL") and at the end of the URL will be: `?code=...`
  3. Make a `POST` request with that code:

       * URL: `http(s)://[HOSTNAME]/login/oauth/access_token`
       * Body:

         ```json
         {
           "client_id": "[CLIENT_ID]",
           "client_secret": "[CLIENT_SECRET]",
           "code": "[CODE]"
         }
         ```

  4. Your token key will be in the response:

     ```text
     access_token=[TOKEN_KEY]&scope=repo&token_type=bearer
     ```

  </details>

## Initialization

1. Clone this repository
2. Navigate into `codeowners-helper/`

## Usage

### Analyze Repos

**Description:** This will audit the existing repos belonging to one team to determine the location of CODEOWNERS files and whether there are any missing and/or extra users listed.

**Required Parameters:**

* Hostname associated with the GitHub Enterprise
* OAuth token key
* Name of the organization of which the team belongs
* Name of the team

**Run:**

   ```command
   # Without CLI parameters
   ruby ./analyze_codeowners.rb

   # With CLI parameters; order is enforced
   ruby ./analyze_codeowners.rb [HOSTNAME]
   ruby ./analyze_codeowners.rb [HOSTNAME] [TOKEN_KEY]
   ruby ./analyze_codeowners.rb [HOSTNAME] [TOKEN_KEY] [ORGANIZATION_NAME]
   ruby ./analyze_codeowners.rb [HOSTNAME] [TOKEN_KEY] [ORGANIZATION_NAME] [TEAM_NAME]
   ```

**Features:**

* Option to remove team members
* Option to remove repos
* Detailed results displayed in tables
* Color- & symbol-coded messages for easy reading

## Notes

* If you don't know your organization and team name, you can find ones you belong to by running this:

  ```command
  curl -u "[YOUR_GITHUB_USERNAME]" http(s)://[HOSTNAME]/api/v3/user/teams
  ```

## Contributing

Pull requests are welcome. For major changes, please open an issue first to discuss what you would like to change.

## License

[MIT](https://choosealicense.com/licenses/mit/)
