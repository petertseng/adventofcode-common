# Advent of Code common

## Test runner

Common test runner for Advent of Code, since I have many solutions in different years and different languges.

**No test inputs are provided in this repo**, by the request of the Advent of Code team.

While the act of publicly posting inputs is [not actively discouraged](https://www.reddit.com/r/adventofcode/comments/e7khy8/are_everyones_input_data_and_by_extension/faofziv/), it is still [preferred](https://www.reddit.com/r/adventofcode/comments/e9p81a/advent_of_code_in_a_different_language_every_day/fal59uy/) that we do not do it.

Therefore, to use this test runner, you will have to provide it your own test cases.

I considered only posting sample inputs (provided in the problem statements publicly to all players, not to any one specific player) in this repo, and then I'd be able to publicly demonstrate (via Travis CI) that my solutions work on those sample inputs, but I considered this not worth it, and also potentially in violation of the team's wishes, since there definitely is an edict against posting puzzle statements.

Expected test format:

Place tests in directory matching this form: {sample,secret}-cases/20??/
In any such directory:

* Tests for a day start with the zero-padded day number, then any arbitrary string afterward.
* An input file ending in .in may be given, or argv arguments may be given in a file ending in .argv.
  Behaviour if both are provided is unspecified but the test runner currently does not respect both.
* Corresponding output file ends in .out.

For example a test might be sample-cases/2015/01a.in and sample-cases/2015/01a.out
