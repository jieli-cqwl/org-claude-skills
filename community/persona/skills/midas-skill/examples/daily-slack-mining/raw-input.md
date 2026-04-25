# Raw Input — Daily Slack Mining (Flagship Example)

> What the user fed Midas: one week of unfiltered Slack messages from a mid-size tech company (~180 employees). Three channels + 4 DMs. ~73 messages total. Dates: 2026-04-02 to 2026-04-08.

This is the kind of input that looks like "nothing" to the average person scanning Slack on a Monday morning. Watch what Midas pulls out of it.

---

## #engineering

**[Tue 10:14 AM] Marcus Chen**
morning everyone. heads up — Jira is crawling again. took me 40 seconds to load the sprint board. anyone else?

**[Tue 10:16 AM] Priya Nair**
same. I just gave up and went back to the spreadsheet

**[Tue 10:17 AM] Dave Liu**
lol "went back to the spreadsheet" in 2026. that's dark.

**[Tue 10:19 AM] Marcus Chen**
@Dave Liu I'm serious btw. I maintain a shadow spreadsheet of our sprint because Jira is unusable half the time. Been doing it for like a year.

**[Tue 10:22 AM] Priya Nair**
wait you maintain a shadow spreadsheet? how long does that take every week?

**[Tue 10:23 AM] Marcus Chen**
probably 4-5 hrs/week. I just copy-paste status updates into my own doc so I can actually see what's going on.

**[Tue 10:24 AM] Priya Nair**
dude that's insane. that's literally a whole morning per week

**[Tue 10:25 AM] Dave Liu**
ok that's actually a problem. can we raise this in the retro?

---

**[Wed 2:47 PM] Sarah Okonkwo**
hey team, FYI the AWS bill came in. $47,312 this month. that's up 18% from last month. CFO is going to want a story by Friday.

**[Wed 2:49 PM] Marcus Chen**
oh god

**[Wed 2:51 PM] Ray Patel**
where's the spike? compute? s3?

**[Wed 2:52 PM] Sarah Okonkwo**
mostly EC2. looks like we spun up a bunch of dev instances for the Q1 migration and nobody killed them. classic.

**[Wed 2:53 PM] Dave Liu**
yeahhh. we have no tagging discipline so it's almost impossible to figure out which team owns what. someone should really build us an internal dashboard that maps instance IDs to team owners.

**[Wed 2:55 PM] Ray Patel**
wait we don't have that? isn't there like a vendor for this?

**[Wed 2:56 PM] Sarah Okonkwo**
we looked at one. $800/month minimum, plus implementation. CFO said no.

**[Wed 2:57 PM] Dave Liu**
lmao so instead we'll burn $8k in excess spend every month while we argue about the $800 tool

**[Wed 3:01 PM] Sarah Okonkwo**
correct

---

**[Thu 11:05 AM] Priya Nair**
anyone free for a quick sync on the payment flow refactor? 15 min max

**[Thu 11:06 AM] Marcus Chen**
can't, in interviews all morning. ask Rafael?

**[Thu 11:07 AM] Priya Nair**
cool ty

---

**[Fri 9:32 AM] Sarah Okonkwo**
morning. quick PSA — the onboarding flow for new engineers is a disaster right now. Rafael started Monday and it took him until Thursday to get his dev env running. we need to fix this.

**[Fri 9:34 AM] Marcus Chen**
lol yes. I started 8 months ago and it took me a full week. we literally have no documented setup script.

**[Fri 9:35 AM] Dave Liu**
and we've hired 6 people this quarter. that's like 30 engineer-days wasted just on onboarding pain.

**[Fri 9:37 AM] Sarah Okonkwo**
I'll put it on the agenda for the next team lead meeting. but realistically we won't have bandwidth to fix it until Q3.

**[Fri 9:38 AM] Dave Liu**
so for the next quarter, new hires will continue to burn a week each. awesome. love it.

---

## #general

**[Mon 9:15 AM] HR — Jenna Kim**
good morning everyone! reminder that Wellness Wednesday this week is a 45-minute meditation session at 12pm. RSVP in the doc.

**[Mon 9:18 AM] Marcus Chen**
💀

**[Mon 9:20 AM] Priya Nair**
I love how HR thinks meditation will fix burnout from 4-hour sprint planning meetings

---

**[Tue 12:34 PM] Jenna Kim**
has anyone found a good place to print business cards quickly? I need some for the conference next week and Vistaprint says 5-7 business days which won't work.

**[Tue 12:36 PM] Ray Patel**
theres that place on 5th? I think they do same-day

**[Tue 12:37 PM] Jenna Kim**
oh really? what's it called

**[Tue 12:38 PM] Ray Patel**
uhh I don't remember. something with "print" in the name lol. it's next to the bagel place

**[Tue 12:39 PM] Jenna Kim**
helpful thanks 🙃

---

**[Wed 4:11 PM] Marcus Chen**
ok WHY is our expense report tool this bad. I just spent 25 minutes trying to submit a $38 Uber receipt and it keeps rejecting the upload because the filename has a space.

**[Wed 4:12 PM] Dave Liu**
THE FILENAME HAS A SPACE?? that's what triggers the rejection?

**[Wed 4:13 PM] Marcus Chen**
yes. I had to rename "IMG 4837.png" to "IMG4837.png" and re-upload

**[Wed 4:15 PM] Jenna Kim**
oh that's a known issue. I tell every new hire during onboarding to always rename files before uploading. I should really add it to the FAQ but honestly the whole tool is so bad we're going to replace it eventually

**[Wed 4:16 PM] Dave Liu**
"eventually" = forever

**[Wed 4:17 PM] Jenna Kim**
😂 pretty much

---

**[Thu 6:45 PM] Rafael Gomez**
hey all — new here. finally got my dev env working 🎉 thanks to everyone who helped, especially Marcus for the 2-hour pairing session on Tuesday

**[Thu 6:46 PM] Marcus Chen**
welcome officially! btw I kept notes from our session. happy to turn them into a setup guide if anyone wants

**[Thu 6:47 PM] Priya Nair**
YES PLEASE. every new hire goes through the same hell

**[Thu 6:48 PM] Sarah Okonkwo**
Marcus if you write that up I owe you a beer. seriously.

---

**[Fri 3:22 PM] Priya Nair**
random question for the group — does anyone know a good freelance designer? we need some icons for the new mobile feature and our design team has no bandwidth until June.

**[Fri 3:24 PM] Jenna Kim**
what kind of icons? I used someone for the conference deck who was cheap and fast

**[Fri 3:25 PM] Priya Nair**
like 20 custom icons matching our brand. not generic ones

**[Fri 3:27 PM] Jenna Kim**
oh that's more than my person does. let me ask around.

**[Fri 3:28 PM] Dave Liu**
I know a guy from my old company but he's usually booked out 4-6 weeks

**[Fri 3:29 PM] Priya Nair**
that's basically forever. I'll keep asking around. thanks

---

## #random

**[Mon 7:15 PM] Dave Liu**
that new taco place on 5th is actually incredible. $12 for 3 tacos and a drink, portions are huge. my partner and I went twice this weekend already

**[Tue 1:10 PM] Marcus Chen**
^ can confirm. got takeout from there yesterday. way better than the food trucks we usually go to

**[Wed 7:30 PM] Priya Nair**
ok I finally tried the taco place you guys won't stop talking about. obsessed. we need to do a team lunch there

**[Thu 12:00 PM] Dave Liu**
the taco place is packed at lunch today btw. line out the door. they're going to blow up

---

## DMs

### DM: Marcus Chen → Priya Nair

**[Wed 6:32 PM] Marcus Chen**
hey — random but I've been thinking about what you said re: my shadow spreadsheet. I realized I've been doing this for a YEAR. It's basically a full-time side project. Do you think other PMs have the same problem?

**[Wed 6:35 PM] Priya Nair**
100%. I know at least three PMs at other companies who complain about Jira constantly. why

**[Wed 6:36 PM] Marcus Chen**
just thinking. I wonder if I could turn the spreadsheet into a proper tool

**[Wed 6:37 PM] Priya Nair**
omg yes. do it. I would pay for that myself

---

### DM: Sarah Okonkwo → Marcus Chen

**[Thu 5:12 PM] Sarah Okonkwo**
hey marcus — off the record, the CFO really does want someone to figure out the AWS tagging situation. if you wanted to take a weekend on it I could probably get you a small bonus or comp time. no pressure obviously

**[Thu 5:14 PM] Marcus Chen**
interesting. let me think about it. is there a budget for external help on this too? or is it purely internal?

**[Thu 5:15 PM] Sarah Okonkwo**
honestly if someone could solve this end-to-end for under $5k we'd probably pay it. the monthly savings would cover it in a week

**[Thu 5:17 PM] Marcus Chen**
noted. let me come back to you on this.

---

### DM: Priya Nair → Marcus Chen

**[Fri 4:05 PM] Priya Nair**
hey — you remember how I asked about freelance designers in #general today? this has been an issue for like 6 months. every team needs icons and design work and our internal team is always booked. it's a huge bottleneck. I almost feel like there's a market for a "on-demand icon shop for dev teams" or something

**[Fri 4:07 PM] Marcus Chen**
lol you and I have the same disease. everything looks like a startup to us

**[Fri 4:07 PM] Priya Nair**
😂 guilty

---

### DM: Jenna Kim → Dave Liu

**[Fri 5:30 PM] Jenna Kim**
hey dave — random but you said your partner is a graphic designer right? is she taking freelance work? Priya was asking for someone earlier and our existing freelancer is too slow

**[Fri 5:32 PM] Dave Liu**
she does take freelance yeah but she charges like $150/hr for icon work

**[Fri 5:33 PM] Jenna Kim**
oh that's probably out of budget for Priya. but good to know

**[Fri 5:34 PM] Dave Liu**
she's really good tho

---

## Summary of input

- **Channels:** #engineering, #general, #random
- **Messages:** ~73
- **People involved:** Marcus Chen, Priya Nair, Dave Liu, Sarah Okonkwo, Ray Patel, Jenna Kim, Rafael Gomez (+ a few drive-by emojis)
- **Time window:** Mon April 2 → Fri April 8, 2026
- **Nothing remarkable happened.** No incidents, no big launches, no drama. Just a normal week.

This is the point. **This is what signal-dense ore looks like to a trained extractor.** See `extracted-signals.md` for what Midas found in it.
