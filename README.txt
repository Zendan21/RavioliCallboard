RavioliCallboard 1.0.4
Author: Zendan

Build an ordered Project Ebonhold Callboard quest route. RavioliCallboard rolls
for the current step, selects only that quest, waits for completion, and then
moves to the next step.

Interface
- The interface follows Ravioli Family Activity Finder's layout and styling:
  a 60-pixel header, left action rail, central searchable catalogue, right route
  panel, flat charcoal surfaces, slate borders and gold interaction highlights.
- Settings, saved routes, quest details, the mini runner and group progress use
  the same panel, header, button, input and semantic colour treatments.

Getting started
1. Type /rcb to open the route builder.
2. If AutoCallboard is enabled, press Import to copy its learned quest catalogue.
   Only catalogue entries are copied; wanted quests, profiles and debug logs are not.
3. Search the catalogue and press + to add quests to the route.
4. Press ? beside any quest to see its exact objective, zone and quest ID.
5. Click zone headers to collapse or expand their quests.
6. Reorder route steps with Up and Down.
7. Open or summon the Callboard so its quest window is visible.
8. Press Start Route. The route cannot start while the window is closed.

Saved routes and settings
- Press Routes to save the current ordered route under a name, load a preset,
  overwrite it after editing, or delete it with a two-click confirmation.
- The Routes window can privately share the current route with a character by
  name. The recipient gets an Accept/Decline prompt, and accepted routes are
  saved as a separate named copy without interrupting their current route.
- Shift-click a player's name in chat to copy it directly into the route-share
  recipient box. The chat name keeps its normal click behaviour as well.
- Every saved-route row has its own Share button, so a preset can be sent
  directly without loading it. Share Current remains available for unsaved edits.
- Incoming routes normally show an Accept/Decline popup. They are also placed in
  a small fallback inbox: use /rcb accept or /rcb decline if no popup is visible.
- Sending a route to your own logged-in character is supported for testing.
- Route sharing includes quest order, objectives, zones and the loop setting.
  Both players need RavioliCallboard installed; transfers use private addon
  whispers and are split automatically when a route is too large for one message.
- Press Settings to enable route looping, change safe auto-accept, set the
  maximum rerolls per step, adjust the reroll response delay, or choose how
  many route quests (1-20) the mini window displays.
- Settings also control automatic group sharing and live group progress.
- Auto-loop is stored with each named route when it is saved.
- The Callboard will not repeat a quest until three different Callboard quests
  have been completed. Auto-loop therefore requires at least four different
  quests, and invalid short loops are refused before any reroll can spend gold.
- RavioliCallboard remembers the last three completed route quests per character,
  even after reloading or switching saved routes, and stops safely if the current
  step is still repeat-locked.
- The board button displays its remaining summon cooldown in seconds. Near a
  permanent city Callboard it changes to Open Board and uses that board instead.

Route runner
- Start Route first looks for an in-range Callboard or Objectives Board. It opens
  permanent city boards and existing summoned boards without casting. Only when
  no usable board is nearby and Summon Callboard is learned does it cast the
  ability, interact with the new board, and start the route.
- Casting Summon Callboard manually while a route is ready also opens the new
  board and starts the route. Manual summons during an active route are detected
  and used for the current step without requiring the addon button.
- Start Route never attempts to recast Summon Callboard while the spell is on
  cooldown. It searches for the existing manually summoned board instead, so a
  cooldown cannot block starting the route or collecting the next route quest.
- When running, the large route builder is replaced by a movable, resizable mini
  window showing the current and upcoming route quests, summon cooldown and a
  clear STOP button. The current quest is highlighted in yellow.
- STOP immediately ends automation and returns to the route builder.
- Accepted route quests are automatically shared with the party or raid when
  the quest is shareable.
- Press Group on the mini runner to open a live, scrollable progress roster.
  Members report objective totals such as 6/10, Complete or Quest not found.
- Live progress uses WoW addon messages, so each tracked group member needs
  RavioliCallboard installed. Anyone without it appears as No addon data.
- A refreshed offer list is searched immediately instead of waiting out a stale
  reroll timeout, making normal Callboard searches substantially faster.
- The exact current route quest advances automatically when the quest log or
  quest completion event reports it complete.
- Ebonhold active-objective transitions are also tracked, so reopening the
  Callboard after finishing a quest immediately begins searching for the next
  route step even when no normal quest-log completion event was emitted.
- If the client blocks automatic interaction, move closer and interact with the
  Callboard manually. Paid rerolls remain blocked until its window is visible.

Commands
/rcb                 Toggle the route builder
/rcb start           Start or resume the route
/rcb pause           Pause automation
/rcb next            Mark the current step complete and advance
/rcb reset           Return to route step 1
/rcb group           Toggle the live group-progress roster
/rcb share NAME      Privately share the current route with that character
/rcb accept          Accept and save the latest incoming shared route
/rcb decline         Decline the latest incoming shared route
/rcb import          Import learned quests from AutoCallboard
/rcb status          Show current route status
/rcb help            Show command help

Important
- Disable AutoCallboard after importing its catalogue with /acb toggle. Running
  two Callboard automation engines together can make both react to the same board.
- RavioliCallboard only auto-accepts a quest when its ID or title matches the
  current route step.
- Completing a step with automatic detection or /rcb next updates the remembered
  three-quest repeat lockout.
- If this client does not emit QUEST_TURNED_IN, use the Next button after you
  finish a step. RavioliCallboard also detects completed quests leaving the log.
