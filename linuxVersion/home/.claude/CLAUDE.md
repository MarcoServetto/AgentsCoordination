This Ubuntu machine is dedicated to Claude: remote-controlled, nobody at the keyboard. Four agents run here,
each in its own folder: linux1 in `/data/fearlessBranch1`, linux2 in
`fearlessBranch2`, linux3 in `fearlessBranch3`, linuxCoordinator in
`/data/linuxCoordinator`.
Every instruction, skill and script on this machine originally comes from the `linuxVersion/` folder of the checkout of
https://github.com/MarcoServetto/AgentsCoordination at `/data/AgentsCoordination` (`windowsVersion/` describes the Windows machine).

The current local copy can deviate from it, at regular intervals the user will discuss the changes and decide what should be kept, what should be reverted, and what should be added to AgentsCoordination via PR.

# Never include history of events in skills and CLAUDE.md files

Describe the current desired behaviour only.
The text should read as if the current version was the only version it ever existed.
Rationale, when needed, is a timeless
present-tense constraint ("jars aren't byte-reproducible"), never a story.

# Never include history of events in code or code comments.

The code should read as if the current version was the only version it ever existed.

# Repositories:
While working with the user, you are going to fork and branch all of those repositories and suggest changes by opening PRs.

https://github.com/MarcoServetto/AgentsCoordination
We keep all the agents configurations and instructions.

https://github.com/FearlessLang/Frontend
https://github.com/FearlessLang/Coordinator
https://github.com/FearlessLang/Commons
https://github.com/FearlessLang/StandardLibrary
The four main Fearless repositories.

https://github.com/FearlessLang/Controllers
A system to manage multiple fearless projects interacting; it also includes an eclipse plugin.

https://github.com/MarcoServetto/FearlessTour
https://github.com/MarcoServetto/ZeroToHero
Fearless guide and game to teach fearless.

# Fearless paper

`/data/fearlessPaper/Fearless_TOPLAS/` is the paper formalizing Fearless, a git repository; build it with `latexmk -pdf --shell-escape -interaction=nonstopmode main.tex`.
Its type system and `Frontend/FearlessFrontend/src/typeSystem` describe the same language: a bug found in one is checked in the other.

# Scripts

Building, testing and packaging Fearless is done only by the Java programs
in `Coordinator/Build/src/scripts/` (see "Fearless" below).
Whitelisted scripts:
- the java scripts in `Coordinator/Build/src/scripts/` (you can run them)
- `/data/AgentsCoordination/linuxVersion/home/.claude/skills/check-claude-usage/check_usage.sh` (you can run it as part of the skill)
- `/data/AgentsCoordination/linuxVersion/home/.claude/skills/align-branches/align-branches.sh` (you can run it as part of the skill)
- `/data/AgentsCoordination/linuxVersion/autoScripts/agent-supervisor.sh` (runs automatically from logon, you can inspect it and fix it when asked)
- `/data/AgentsCoordination/linuxVersion/autoScripts/cleanup-watchdog.sh` (called hourly by the above)
- `/data/AgentsCoordination/linuxVersion/reset.sh` (resets the machine to what the repository describes and reboots; run it only when asked to reset the machine, see installation.txt)

Never add a long lived `.sh`/`.py` without permission, and if/when added, add to this white list.
Of course you can make short lived scripts to run them during your normal tasks, just make sure to clean them up later and leave no trace they ever existed. 

# Character set:
When possible only use those characters
0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ+-*/=<>,.;:()[]{}`'"!?@#$%^&_|~\
space and new line (\n only)
This includes any text you write anywhere, any file name etc.
This is a soft rule and there are plenty of reasons a task may require to use other characters; one obvious exception is "you are reporting verbatim something that already exists" or "you are updating a part of a document and you should leave the rest alone"


# Accounts

We keep the description of your email and github accounts in '/data/accounts.txt'

These are yours: commit, push, open issues and PRs as this identity without
asking. Password, token and 2FA all live in '/data/accounts.txt'

# PRs:
When asked to make a PR, it means on the upstream parent org (FearlessLang, MarcoServetto).
When considering making a new PR: look if we can just amend the existing PR instead.
When considering amending a PR: look if it has already been merged,
Before closing any PR, comment why.
There is no auto-merging, ever: Marco reviews and merges/closes every PR by hand.
Example commands: `gh pr create --repo <PARENT> --base main --head marcoautomation2:<branch>`
(both the --repo and the marcoautomation2: prefix are required)
`gh pr view <n> --repo <PARENT> --json state,mergedAt`

# Managing Disk:

Everything on the machine is fair game; prefer `/data` (short paths, no spaces).

Everything on this machine is disposable, all the important data is kept on the original repositories.

# Elevation

agentubuntu has passwordless sudo. Install, uninstall, write /etc and
/opt, manage services, register autostart entries; directly, without
asking. Anything writing to an agent's `/run/user/1000/cc-socks/<pid>.sock`
socket must run as agentubuntu.

# Shared memory and shared CLAUDE.md

linux1,linux2,linux3 and linuxCoordinator internal CLAUDE.md should contain a single line "Do not add anything to the local CLAUDE.md, we keep a single source of truth".
linux1,linux2,linux3 and linuxCoordinator local memory should only report:
"Do not use this local memory, all the data is in '/data/AgentsCoordination/linuxVersion/global_memory.txt'; add and remove from there when/if needed"
Those files are the ones under `linuxVersion/data/` and `linuxVersion/home/` of AgentsCoordination; reset.sh writes them.
Changes to `global_memory.txt` are local and are unlikely to cause a PRs to AgentsCoordination.


# Inter agent messaging

linux1,linux2,linux3 and linuxCoordinator should not talk with each other.
linux1,linux2,linux3 and linuxCoordinator can talk with their sub agents and those can of course reply back.
(The startup script is not an agent: the messages it delivers at their
scheduled time are normal user input, and answering one is not talking to
another agent)
Occasionally the user will explicitly ask to message another linux1,linux2,linux3 and linuxCoordinator agent to delegate a specific task.
This is ok when asked but:
- provide full context on the task in one shot
- do not ask anything back
- the other agent will take up the task and only discuss the results with the user, not with other agents


# Overnight tasks

linux3 takes care of overnight tasks.
When woken up with run_overnight_tasks:
- The user is asleep, asking anything to the user will block the whole overnight process.
- read https://github.com/MarcoServetto/ZeroToHero/blob/main/tasksLinux/LongHorizonTasks.txt
- if that file does not exist or lists no tasks, do no tasks and stop.
Repeat the following:
(1)- check the time
  if it is after 8am, stop.
(2)- Use the check-claude-usage skill
If the "Current session" is less than 70%, start a task;
else sleep until the "Current session" is over, then go to (1).

Starting a task:
A task need to be started in a sub agent (sonnet max)
Focus on not trying to understand the tasks but just delegating them; just collect compacted informations about the results.
The sub agent should write a log of its actions and conclusions.
The task will contain info on how to communicate the results to the user.
If a task needs discussion in the morning, the user should ask to delegate it to linux1/linux2; give full context by pointing to the logs of the sub agent.

After stopping because no more tasks, no more time or some other reason, do a PR to ZeroToHero moving the done tasks into the done file, and the text of the PR should be a report on what happened in the night.


# Machine-health review (linuxCoordinator)

When you receive run_daily_check_up
check the general machine health.
Check for the activities of `cleanup-watchdog.sh` in `/data/linuxCoordinator/logs/diagnostic.log` (`ATTENTION` lines are what it noticed but did not act on), check the disk space and accumulated trash, check for the self consistency of all the scripts, memories and CLAUDE.md files. Write a numbered bullet point list of what you propose to do and wait for the user to give instructions; do not act, just monitor.
A bare `scheduler_failed` message means the polling loop of `agent-supervisor.sh` has died: nothing in `scheduledTasks.txt` fires again until the next logon. Report it the same way.

# Remote

The user is always remote: nobody is at this machine's keyboard. Anything
the session offers that assumes a person sitting here does not apply -
never suggest `! <cmd>` for the user to run, and never hand over a result
as a local file. Put what the user needs to see in the chat reply.

# Fearless

Seven sibling repos per working copy, each with `origin` = the
marcoautomation2 fork and `upstream` = the parent org: `FearlessLang/<name>`
for Commons, Frontend, Coordinator, StandardLibrary, Controllers;
`MarcoServetto/<name>` for ZeroToHero, FearlessTour. Never commit a
CLAUDE.md or any Claude-local config into them.

At the start of new work in a `fearlessBranch*` folder, run the align-branches skill

Note the file `Coordinator/Build/src/resources/LocalResources.java` (gitignored, machine-specific: `LocalResourcesTemplate.java` from the same folder, keeping `package resources;`, with `prefix` set to the branch folder) must exist in each working copy.
Details:

Commons          shared, dependency-free Java utilities. Everything else depends on this; it depends on nothing here.
Frontend         the Fearless language frontend (parser, name resolution, type inference). Depends on Commons.
Coordinator      the compiler backend and CLI (the portable Fearless). Depends on Commons and Frontend.
StandardLibrary  Fearless SOURCE code, not Java: the language's own base library ("base"), its runtime ("rt"), and a folder of integration-test Fearless projects. This is compiled and run BY Coordinator, not built with javac.
Controllers      a system to manage multiple fearless projects interacting; it also includes an eclipse plugin. Depends on Coordinator.
ZeroToHero       Game to teach fearless and overall scratch pad for a lot of stuff.
FearlessTour     a guide to teach fearless (including tests to run to check consistency with the current state of the language)

Line endings matter: the repositories carry LF-committed sources, and some
tests compare generated output against expected text byte for byte. All the repos should be set up to enforce this.


The Java scripts:
We run and test fearless by running Java, not shell scripts.
From `Coordinator/Build/src` you can run the following (note, no arguments)
(new java do not need a separate compile step)
  /opt/jdk-26.0.2/bin/java -ea --module-path ../../../Commons/Commons.jar --add-modules Commons scripts/<Name>.java
`Coordinator/Build` is the build tool for all the repos, written in Java and
compiled by nothing but this source launcher; `Build/src/resources` is also
compiled into Coordinator's tests, which read paths from it.

`Commons.jar` is committed to the Commons repository itself specifically so
it is present and ready immediately after cloning or updating.
If a PR changes the logical content of Commons, a new Commons.jar needs to be added to the PR. Copy the regenerated `out/modular/mods/Commons.jar` over `Commons/Commons.jar` yourself and commit it as part of the PR.

  TestAllFrontend.java
    Builds Commons and Frontend and runs Frontend's test suite. Fast -
    seconds, not minutes.

  TestAllFrontendCoordinator.java
    Builds Commons, Frontend, and Coordinator, and runs Coordinator's test
    suite EXCLUDING its slow `integrationTests` package (which would compile
    and actually runs whole example Fearless programs, one JVM launch per
    project). Fast. Test `testBuildBase.TestBuildBase` builds the standard library 'base' but does not save it in the cache for integration tests.

  TestAllFrontendCoordinatorIntegration.java
    Builds and runs everything the previous two programs do, PLUS
    Coordinator's `integrationTests` package. Slow - minutes, not seconds.

  TestAllController.java
    Builds Commons, Frontend, Coordinator, and Controllers (the `Controller`
    module, which depends on Coordinator), and runs Controllers' JUnit test
    suite except its `agentTools` package. Fast.

  TestAgentTools.java
    Same build, then only Controllers' `agentTools` tests: `DesktopDragTest`
    drives the real desktop through `agentTools.Pilot` (pointer, keys,
    screenshots), opening two folder windows on the Desktop and dragging a
    file between them. It takes the pointer and keyboard away from every
    agent on this shared desktop: run it only when asked.

  DeployPortableFearless.java
    Builds a self-contained, runnable application image of the Fearless
    compiler/runner (the "portable" build). It also invokes jlink and
    jpackage.
  (When testing, note that the portable binary needs a project folder as its argument; with none it opens a welcome GUI and never exits)

  DeployManagedFearless.java
    Builds Commons, Frontend, Coordinator and Controllers, then packages
    them into a self-contained, runnable application image of the Managed
    Fearless GUI (entry point `Controller/controller.Main`). It also invokes
    jlink and jpackage.

Every dependency jar they need is already checked in, nothing needs a separate download - but from two different folders, kept deliberately separate:
`Coordinator/externalJars/` (what a *running* Fearless program needs, ends up bundled inside DeployPortableFearless/DeployManagedFearless's
built application image)
`Coordinator/testJars/` (JUnit and jspecify, needed only to compile and run the test suite, and not bundled into anything shipped).


## Java

JDK 26 is the folder `/opt/jdk-26.0.2`, unpacked by hand;
never install a JDK (no apt) and never rely on `java` from
the PATH: call this one by its full path: `/opt/jdk-26.0.2/bin/java -ea ...`.
`JAVA_HOME` is unset. Assertions are always on: always pass `-ea`.


## StandardLibrary API docs

Compiling a Fearless package writes `<pkg>.txt`: a plain-text rendering of types, signatures and doc comments meant for agents.
Example locations:
/data/fearlessBranch1/StandardLibrary/dbgOut/baseCache/base.txt
/data/fearlessBranch2/StandardLibrary/fearlessArtefact/fearlessBin0_001/app/stdLib/baseCache/base.txt
/data/fearlessBranch2/StandardLibrary/integrationTests/helloWorld/.fearless_out/gen_java/hello.txt


## Commons

Prefer `Commons/src/{utils,offensiveUtils,tools}` over rolling your own;
`Bug` (`unreachable`/`todo`/`of`/`err`), `OneOr` (exactly one stream element; use it instead of `findFirst` whenever one result is assumed), `Join`, `Push`, `Pop`, `Range`, `Box`, `GetO`, `Mapper`, `DistinctBy`, `Streams`/`Zipper2`/`Zipper3` (same-length asserted zips),
`Err` (test matcher with `[###]` holes), `Pos`, `ThrowingConsumer`/
`ThrowingFunction`, `UriSort`. `offensiveUtils`: `Require` (`check` is the
one unconditional guard; the rest compose inside `assert`),
`EqTransparent`/`@NeverAsKey`. `tools`: `Fs` (filesystem, `runTool`, the
`allowed` character set), `JavacTool`, `JavaTool` (child JVM),
`PortableApp`, `SourceOracle`, `Zips`, `ReadZip`, `ZipWalk`.

# Coding rules

## Offensive programming

Offensive programming is good, defensive programming is bad; including
implicit offensive programming (letting a bad input fail loudly on its own
rather than guarding against it).

Expect non-null: call methods on it directly.

You need a positive number where a negative one would only produce nonsense? do `assert x>=0;`, with no message.

All code that can't reliably be made to run shouldn't exist;
bad attitude: "This may be A or B, I'll handle both so the code flexibly adapts". This causes one branch to be dead, untested code.
The exceptions are `Bug.unreachable()` and checks inside `assert consistent()` that may accept early.

Functional programming is full of those bad defensive patterns: A `zip` that silently ignores elements past the shorter input hides errors.
Instead we should assert equal length first.
`stream.findFirst()` often hides an assumption of a single result; use `OneOr`.

Offensive assertions need no message: `return Objects.requireNonNull(image);`
or just `return image;`, not `assert image != null: "load() runs first"`. 

`assert x!=null;`, `Objects.requireNonNull(x)` and `Require.nonNull(x)` are all correct offensive checks; good to use in different roles (requireNonNull returns the value, Require.nonNull allows for multiple checks all together).

Graceful degradation is the enemy: immediate hard failures, via assertions when reasonable.

## Style

If a condition is longish, pull it into a local variable. Always brace
`if`/`for`/`while`; keep short ifs on one line: `if (toBeCut){ cutIt(); return; }`.

No blank lines splitting a method into sections. No ALL_CAPS names;
CamelCase for constants and enums too. Only these characters:
```java
public static final String allowed=
  "0123456789" +
  "abcdefghijklmnopqrstuvwxyz" +
  "ABCDEFGHIJKLMNOPQRSTUVWXYZ" +
  "+-*/=<>,.;:()[]{}" +
  "`'\"!?@#$%^&_|~\\" +
  " \n";
```
(mirrored in `Fs.allowed`). Modern Java: streams, lambdas, optionals; no
long inline lambdas; declare a method (`this::foo`, or
`(a,b)->foo(a,b,c,d)`); a lambda needing several statements or returns is
too big.
Switch expressions are good, but factor out a sub-method instead of using `yield`.

- Java collections are either shallow immutable or updatable.
  We use the static type system to hint what is the nature of a collection object. When possible, use ArrayList<T> or other concrete collection types to indicate that we do know the object is updatable, and use List<T> when we can assume is not. In many points we do wrap an ArrayList into List.copyOf or Collections.unmodifiableList to make the transition clear; we may occasionally avoid it for performance in crucial places.

## No adding comments
Do not add comments to generated code. Preserve existing comments literally.

Rationale goes in the chat reply or the PR description, never in the deliverable.

The user will be responsible for adding and removing comments, often to flag something LLMs keep misreading. The one exception is a comment capturing something that took real thinking to work out. As a rule of thumb, if by reading the code you can understand what it does enough to add an explanatory comment, that comment is by definition redundant.

## Minimality

Code must be as small as possible; readability is not a concern. Small code
means the whole codebase can be read; when reasonable, read all of it
before a task. 

Don't pass extracted/generated data across chains of method calls: pass one unit of information and
regenerate locally the needed parts.

Invert ifs to favour early returns and errors, thus erasing `else` branches.

After code is generated and tested, do a second pass purely to shrink it: remove abstractions and indirections that didn't earn
their place; a generalization is worth it only if the current codebase gets
smaller in actual lines. Duplication is far cheaper than the wrong
abstraction; a new concept (a type, an interface method) must earn its
value. 
Not all lines of code are expensive.
Actual code logic in the code that get deployed is expensive.
Testing code is very cheap, and occasionally it is ok if some duplication is present.
Imports at the start of files are free.

Duplication between fearlessPortable and fearlessManager is fine.

Avoid methods that could be easily inlined, for example
 `public static boolean hasConsoleFlag(){ return LauncherProps.hasConsoleFlag(); }`

During testing, when possible check if a string matches the expected result using utils.Err. Do not "assertTrue(text.contains(expected));"

## Refactoring a PR while guided by the user

Accepting a PR will often require a direct chat with the user.
You need to distinguish two kinds of request:
Explain: 'Why this local variable exists' Here the user is asking a question, not providing a suggestion
Amend: 'Remove this local variable' Here the user is giving a direct command.

If your interpretation of a user request ends up growing the code base, probably you misunderstood. Clarify instead of acting.
"Move X into Y, this removes the need for Z".
This is an example of a request that must shrink the diff and remove Z. If your answer adds a type, wrapper record, parameter, boolean flag or file, you have misread it. If the literal request would grow the
code, stop and ask, stating the tradeoff plainly. If it cannot be done without breaking a constraint you weren't told to relax, say exactly what blocks it and ask. Never invent an abstraction during PR reviews in order to somehow match the user request.

## Conventions

Most code out there is bad code; conventions are only sometimes right. In
those projects going against convention is deliberate; embrace the
unconventional setup rather than drifting toward "normal" code. Java is a
tool: rely on its formal semantics, not on its recommended usage.

## Names, messages, tests

- Never put Marco's name or any real person's in code, tests, mock data
  or commit messages; Try to avoid examples requiring person names.
- When reasonable, avoid naming tools that just so happens to be used, like 'eclipse', 'windows', 'firefox' etc. For example `junit_xml` is good, `eclipse_junit_xml` is bad.

- Frontend does a lot of careful work to generate good errors.
  Try to copy that style when possible.
  Many errors in coordinator have been generated by agents and are not as good.
  Overall, accept the fact that you, as an agent, are still pretty bad at generating good error messages and rely on the guidance from the user and the examples in Frontend. Feel free to add <HELP ME WITH WORDING> when you struggle to make a good error.
  Two crucial guidelines: (1)avoid being vague:
  `this type is ill formed` is pointless.
  `The type "A[B,mut C]" is ill formed because A[_,_] second generic argument can not be "mut"; only "imm" and read are accepted.` 
  Note the details; A single line contains:
  the type verbatim instead of general references like 'the type, such type, that type, the type in that position'.
  the technical term (ill formed) the explanation of what is wrong, the list of what is good.
  (2)omitting is ok: limit the information to what is truly useful for the user. Naming what has gone wrong in an internal algorithm is pointless. If something can not be discovered, omitting any mention of that thing is better then being vague.

## Testing GUIs.

One of the core way you are useful is that you can control the PC directly and test guis.
We are keeping a '/data/AgentsCoordination/linuxVersion/gui_gym.txt' where we write the findings on how to best operate the PC to emulate a human user as close as possible: only what holds across a wide range of GUIs (screen, pointer, windows, the OS menus). What is about one application goes in its own file next to it, `gui_<app>_gym.txt` (for example `gui_eclipse_gym.txt`), never in gui_gym.txt.
`Controllers/src/agentTools` (`Pilot`: `glide`, `click`, `drag`, `chord`, `shot`, `changed`) drives the desk the way a person does; prefer it over ad hoc input injection when a test needs real pointer or keyboard input. It is a general purpose API for any agentic harness on any machine: pure Java (`java.awt.Robot`), the same code on windows, X11 and wayland, depending on nothing installed or configured here. The agents on this machine are just one of its users: never add to it anything that assumes this setup (GNOME, D-Bus, python, our installation); what a platform needs from the machine (accepting the wayland consent dialog, keeping the screen from blanking) is documented, never coded around.


## Automated tests.

Run (only) one of TestAllFrontend.java, TestAllFrontendCoordinator.java, TestAllFrontendCoordinatorIntegration.java, TestAllController.java
Depending on the estimate risk of regression.

Only run `/data/AgentsCoordination/linuxVersion/fearlessManagerAutomatedGuiTests/allTests.txt` when asked, since it takes one hour.

# Think, do not jump to probing
You know Java, the JDK and these tools well; rely on that. Explain from the mechanism and act on it. Most questions need no command at all, and the reasoning is worth more than the observation, it produces code that is correct according to the standard not just according to the current behavior on machine today.

# Running commands

The Bash tool is bash, with no stdin, and each call starts in the session's working directory:
- Shell state (variables, functions, `cd`) does not persist between calls; use absolute paths.
- Multi-line text for a command goes through a file or a heredoc (`git commit -F <file>`, `gh pr create --body-file <file>`); `-F -` reads stdin, which is not there.
- Ask `gh` for `--json` and parse with `jq` or `python3 -c`.
- The desktop session is GNOME on Wayland: `DISPLAY`, `WAYLAND_DISPLAY` and `XDG_RUNTIME_DIR` are set in every agent session, so GUI programs started from Bash open on the display.
- Changing `core.autocrlf` on an existing worktree makes every file look modified: the global setting is `false` (installation.txt), so clone rather than flip it.
