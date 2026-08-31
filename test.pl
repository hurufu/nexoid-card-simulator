:- dynamic(t/3).
:- multifile(t/3).
:- discontiguous(t/3).

%% testall.
%
% Fails if at least one test doesn't pass, but still executes all of them no
% matter what while printing report line for each unit test.
%
% Report looks like the following:
%
% ```
% true:[test_name,...]
% false:test_name
% skip:test_name
% error(ErrorTerm):test_name
% ```
%
% Test succeeds if it perfroms according to its expected outcome. Test may
% succeed multiple times.
%
% Test definition looks like this:
%
% ```
% t(Unit, ExpectedOutcome, (TestName :- TestBody)).
% ```
%
% Where:
%   `ExpectedOutcome` is either `true`, `false` or `error(ErrorTerm)` when an exception is expected.
%   `TestName` is a term describing the test (usually an atom)
%   `TestBody` is an actual test case
%
% TODO: Write tips for writting tests
% TODO: Add call_with_inference_limit/3 to detect possible non-termination
% FIXME: There some quirks when using inside modules, because of (:)/2.
testall(U) :- findall(C, testsingle(U,C), _).

pass(true).
pass(skip).

%% testsingle(-TestResult).
%
% Retrieves unit tests and executes it. Always succeeds.
testsingle(U, C) :-
    gettest(U, D, G),
    asserta(D),
    call_cleanup(runtest(U,G,C), retract(D)).

%% gettest(-TestPredicate, -TestQuery).
%
% Retrieves unit test from the datebase, fails if no tests were found or test
% definition is incorrect.
%
% TODO: Throw exception, don't fail.
% FIXME: Handle modules correctly
gettest(U, (H:-B), G) :- t(U, E, (H:-B)), expectation_goal(E, H, G).

expectation_goal(true, H, H).
expectation_goal(false, H, \+H).
expectation_goal(error(E), H, catch(H, error(E, _), true)).
expectation_goal(skip, H, true(H)).

true(_).

%% runtest(+Goal, -ResultCode).
%
% Try to collect all solutions and print predicate outcome no matter what.
% Always succeeds.
runtest(U, G, C) :- catch(findall(G,G,S), E, S = x(E)), what_to_print(S, G, C:R), write(C:U:R), nl.

what_to_print([],          G, false:G).
what_to_print([true(H)|_], _,  skip:H).
what_to_print([H|T],       _,  true:[H|T]) :- H \= true(_).
what_to_print(x(E),        G,     E:G).
