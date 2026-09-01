:- meta_predicate(foldl__(5,?,?,?,?,?)).
%% foldl__(G__3, L1, V0, Vlast)//
%
foldl__(_, [], V, V) --> [].
foldl__(G__3, [H1|T1], V0, Vlast) --> { acyclic_term(T1) }, call(G__3, H1, V0, Vnext), foldl__(G__3, T1, Vnext, Vlast).


%% length__(L, N)//
%
length__(L, N) --> { acyclic_term(L) }, foldl__(count__(noop__, N), L, 0, N).

:- meta_predicate(count__(3,?,?,?,?,?,?)).
count__(T_1, N, E, V0, Vn) --> { \+var(N), V0 =:= N -> false; Vn is V0 + 1 }, call(T_1, E).
noop__(E) --> [E].

between__(L, U, N) --> { between(L, U, N) }, number__(N).
number__(N) --> { number_chars(N, Cs) }, Cs.

int_span__(From, To) --> { To >= From }, foldl__(incr__(To), _, From, To).
incr__(N, _, V0, Vn) --> { V0 =:= N -> false; Vn is V0 + 1 }, [V0].

int_p_span__(From, To) --> { eq(int(From), F), eq(int(To), T) }, foldl__(incr_p__(T), _, F, T).
incr_p__(Max, E, V, s(V)) --> [E], { eq(cmp(lt), V, Max), eq(int(E), V) }.
