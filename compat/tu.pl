%% forall(Generate, Test).
%
% For all bindings possible by Generate, Test must be true.
%
% In this example, it checks that all numbers are even:
%
% ```
% ?- Ns = [2,4,6], forall(member(N, Ns), 0 is N mod 2).
%    Ns = [2,4,6].
% ```
forall(Generate, Test) :-
    \+ (Generate, \+ Test).
