# Introduction to Pleroma
## What is Pleroma?
Pleroma is a federated social networking platform, compatible with GNU social, Mastodon and other OStatus and ActivityPub implementations. It is free software licensed under the AGPLv3.
It actually consists of two components: a backend, named simply Pleroma, and a user-facing frontend, named Pleroma-FE. It also includes the Mastodon frontend, if that's your thing.
It's part of what we call the fediverse, a federated network of instances which speak common protocols and can communicate with each other.
One account on a instance is enough to talk to the entire fediverse!

## How can I use it?

Pleroma instances are already widely deployed, a list can be found here:
http://distsn.org/pleroma-instances.html

If you don't feel like joining an existing instance, but instead prefer to deploy your own instance, that's easy too!
Installation instructions can be found here:
[main Pleroma wiki](/)

## I got an account, now what?
Great! Now you can explore the fediverse!
- Open the login page for your Pleroma instance (for ex. https://pleroma.soykaf.com) and login with your username and password.
(If you don't have one yet, click on Register) :slightly_smiling_face:

At this point you will have two columns in front of you.

### Left column
- first block: here you can see your avatar, your nickname a bio, and statistics (Statuses, Following, Followers).
Under that you have a text form which allows you to post new statuses. The icon on the left is for uploading media files and attach them to your post. The number under the text form is a character counter, every instance can have a different character limit (the default is 5000).
If you want to mention someone, type @ + name of the person. A drop-down menu will help you in finding the right person. :slight_smile:
To post your status, simply press Submit.

- second block: Here you can switch between the different timelines:
  - Timeline: all the people that you follow
  - Mentions: all the statutes where you are mentioned
  - Public Timeline: all the statutes from the local instance
  - The Whole Known Network: everything, local and remote!

- third block: this is the Chat block, where you communicate with people on the same instance in realtime. It is local-only, for now, but we're planning to make it extendable to the entire fediverse! :sweat_smile:

- fourth block: This is the Notifications block, here you will get notified whenever somebody mentions you, follows you, repeats or favorites one of your statuses.

### Right column
This is where the interesting stuff happens! :slight_smile:
Depending on the timeline you will see different statuses, but each status has a standard structure:
- Icon + name + link to profile. An optional left-arrow if it's a reply to another status (hovering will reveal the replied-to status).
- A + button on the right allows you to Expand/Collapse an entire discussion thread. It also updates in realtime!
- A binocular icon allows you to open the status on the instance where it's originating from.
- The text of the status, including mentions. If you click on a mention, it will automatically open the profile page of that person.
- Four buttons (left to right): Reply, Repeat, Favorite, Delete.

## Mastodon interface
If the Pleroma interface isn't your thing, or you're just trying something new but you want to keep using the familiar Mastodon interface, we got that too! :smile:
Just add a "/web" after your instance url (for ex. https://pleroma.soycaf.com/web) and you'll end on the Mastodon web interface, but with a Pleroma backend! MAGIC! :fireworks:
For more information on the Mastodon interface, please look here:
https://github.com/tootsuite/documentation/blob/master/Using-Mastodon/User-guide.md

Remember, what you see is only the frontend part of Mastodon, the backend is still Pleroma.
