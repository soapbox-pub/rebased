# Introduction to Pleroma
## What is Pleroma?
Pleroma is a federated social networking platform, compatible with GNU social, Mastodon and other OStatus and ActivityPub implementations. It is free software licensed under the AGPLv3.
It actually consists of two components: a backend, named simply Pleroma, and a user-facing frontend, named Pleroma-FE. It also includes the Mastodon frontend, if that's your thing.
It's part of what we call the fediverse, a federated network of instances which speak common protocols and can communicate with each other.
One account on an instance is enough to talk to the entire fediverse!

## How can I use it?

Pleroma instances are already widely deployed, a list can be found at <http://distsn.org/pleroma-instances.html>. Information on all existing fediverse instances can be found at <https://fediverse.network/>.

If you don't feel like joining an existing instance, but instead prefer to deploy your own instance, that's easy too!
Installation instructions can be found in the installation section of these docs.

## I got an account, now what?
Great! Now you can explore the fediverse! Open the login page for your Pleroma instance (e.g. <https://pleroma.soykaf.com>) and login with your username and password. (If you don't have an account yet, click on Register)

At this point you will have two columns in front of you.

### Left column

- first block: here you can see your avatar, your nickname and statistics (Statuses, Following, Followers). Clicking your profile pic will open your profile.
Under that you have a text form which allows you to post new statuses. The number on the bottom of the text form is a character counter, every instance can have a different character limit (the default is 5000).
If you want to mention someone, type @ + name of the person. A drop-down menu will help you in finding the right person.
Under the text form there are also several visibility options and there is the option to use rich text.
Under that the icon on the left is for uploading media files and attach them to your post. There is also an emoji-picker and an option to post a poll.
To post your status, simply press Submit.
On the top right you will also see a wrench icon. This opens your personal settings.

- second block: Here you can switch between the different timelines:
   - Timeline: all the people that you follow
   - Interactions: here you can switch between different timelines where there was interaction with your account. There is Mentions, Repeats and Favorites, and New follows
   - Direct Messages: these are the Direct Messages sent to you
   - Public Timeline: all the statutes from the local instance
   - The Whole Known Network: all public posts the instance knows about, both local and remote!
   - About: This isn't a Timeline but shows relevant info about the instance. You can find a list of the moderators and admins, Terms of Service, MRF policies and enabled features.
- Optional third block: This is the Instance panel that can be activated, but is deactivated by default. It's fully customisable and by default has links to the pleroma-fe and Mastodon-fe.
- fourth block: This is the Notifications block, here you will get notified whenever somebody mentions you, follows you, repeats or favorites one of your statuses.

### Right column
This is where the interesting stuff happens!
Depending on the timeline you will see different statuses, but each status has a standard structure:

- Profile pic, name and link to profile. An optional left-arrow if it's a reply to another status (hovering will reveal the reply-to status). Clicking on the profile pic will uncollapse the user's profile.
- A `+` button on the right allows you to Expand/Collapse an entire discussion thread. It also updates in realtime!
- An arrow icon allows you to open the status on the instance where it's originating from.
- The text of the status, including mentions and attachements. If you click on a mention, it will automatically open the profile page of that person.
- Three buttons (left to right): Reply, Repeat, Favorite. There is also a forth button, this is a dropdown menu for simple moderation like muting the conversation or, if you have moderation rights, delete the status from the server.

### Top right

- The magnifier icon opens the search screen where you can search for statuses, people and hashtags. It's also possible to import statusses from remote servers by pasting the url to the post in the search field.
- The gear icon gives you general settings
- If you have admin rights, you'll see an icon that opens the admin interface
- The last icon is to log out

### Bottom right
On the bottom right you have a chatbox. Here you can communicate with people on the same instance in realtime. It is local-only, for now, but there are plans to make it extendable to the entire fediverse!

### Mastodon interface
If the Pleroma interface isn't your thing, or you're just trying something new but you want to keep using the familiar Mastodon interface, we got that too!
Just add a "/web" after your instance url (e.g. <https://pleroma.soycaf.com/web>) and you'll end on the Mastodon web interface, but with a Pleroma backend! MAGIC!
The Mastodon interface is from the Glitch-soc fork. For more information on the Mastodon interface you can check the [Mastodon](https://docs.joinmastodon.org/) and [Glitch-soc](https://glitch-soc.github.io/docs/) documentation.

Remember, what you see is only the frontend part of Mastodon, the backend is still Pleroma.
