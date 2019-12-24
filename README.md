# Codeowners Helper

## Retrieving an OAuth Token

* Sign in to GitHub Enterprise
* Go to this URL in your browser: `http(s)://[HOSTNAME]/login/oauth/authorize?scope=repo&client_id=[CLIENT_ID]`
* It will redirect you and a code will be in the URL now: `?code=...`
* Make a POST request with that code:
  * URL: `http(s)://[HOSTNAME]/login/oauth/access_token`
  * Body:

    ```json
    {
      "client_id": "[CLIENT_ID]",
      "client_secret": "[CLIENT_SECRET]",
      "code": "[CODE]"
    }
    ```

* An access token will return: `access_token=[TOKEN]&scope=repo&token_type=bearer`

## Finding Your Team

If you don't know your organization and team name: `curl -u "[YOUR_GITHUB_USERNAME]" http(s)://[HOSTNAME]/api/v3/user/teams`
