# automatic-deploy
Automatically exports and deploys a godot project to netlify from the editor

## setup
1. Install the addon by copying the `addons/` directory into your godot project then checking `Enable` next to `Automatic Deploy` in the project settings Plugins tab. 
2. Add a new html5 export called "HTML5". Ensure that there are no red warnings (this would mean that the export does not currently work)
3. Make a [netlify](https://netlify.com) account if you don't have one already
4. Go to the [netlify person access token management page](https://app.netlify.com/user/applications#personal-access-tokens) and create a "Personal Access Token".
5. Copy the token into your clipboard, then paste it into the token field on the new `Deploy` tab in the godot editor
6. Note: This token is stored in the editor settings, and should be kept private. If you share your editor settings file with other people, keep this vulnerability in mind. 

You should be all setup now! The token you entered is global and will show up on all projects. By clicking deploy you can now automatically deploy your game to a new site on the internet, then copy and paste the URL to share with somebody to quickly share your game. 
