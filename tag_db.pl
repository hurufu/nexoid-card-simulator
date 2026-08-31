%% EMV tag database %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
:- initialization(db_consistent).

tag_properties_defaults(Id, Kernel, L, D) :- maplist(tag_property_default(Id,Kernel), L, D).
tag_properties(Id, Kernel, L) :- maplist(tag_property(Id,Kernel), L).

tag_property_default(Id, Kernel, Property, Default) :-
    ground(Default),
    (
        \+ tag_property(Id, Kernel, Property) ->
            Property = Default
        ;   tag_property(Id, Kernel, Property)
    ).

tag_property(Id, Kernel, value(Id)) :- tag_db(Id, _, Kernel, _).
tag_property(Id, Kernel, length(L)) :- tag_db(Id, _, Kernel, _), L is ceiling(log(Id + 1) / log(2) / 8).
tag_property(Id, Kernel, name(N)) :- tag_db(Id, _, Kernel, N).
tag_property(Id, Kernel, spec(S)) :- tag_db(Id, S, Kernel, _).

%% fmt(FormatSpecification)// is multi.
%
% Data element specification format.
fmt(false) --> fmt_false.
fmt(template) --> fmt_template.
fmt(element(F,constraint(C,L,U))) --> fmt_format(F), { fmt_constraint(F, C), fmt_max_unspec(M, Y) }, fmt_lower_upper(M, Y, L, U).
fmt_template --> [t].
fmt_false --> [-].
fmt_format(b) --> [b].
fmt_format(n) --> [n].
fmt_format(cn) --> [c,n].
fmt_format(a) --> [a].
fmt_format(an) --> [a,n].
fmt_format(ans) --> [a,n,s].
fmt_format(var) --> [v,a,r].
fmt_range --> [.,.].
fmt_any --> [.,.,.].
fmt_unspec --> [v,a,r].
fmt_spc --> [' '].
fmt_lower_upper(_, Y, 0, Y) --> fmt_any, fmt_unspec.
fmt_lower_upper(M, _, 0, U) --> fmt_any, between__(1, M, U).
fmt_lower_upper(M, Y, L, Y) --> { between(1, M, L) }, fmt_spc, fmt_unspec.
fmt_lower_upper(M, _, L, L) --> between__(1, M, L).
fmt_lower_upper(M, Y, L, Y) --> between__(1, M, L), fmt_range, fmt_unspec.
fmt_lower_upper(M, _, L, U) --> between__(1, M, L), fmt_range, between__(1, M, U), { L < U }.
fmt_constraint(cn,  bcd ).
fmt_constraint(n,   bcd ).
fmt_constraint(b,   byte).
fmt_constraint(a,   byte).
fmt_constraint(an,  byte).
fmt_constraint(ans, byte).
fmt_max_unspec(252, 253).
%fmt_max_unspec(252, 16).
%fmt_max_unspec(252, _).

tag_spec_db(T, K, S, N) :-
    tag_db(T, K, Atom, N),
    atom_chars(Atom, Codes),
    phrase(fmt(S), Codes).


%% tag_db(EmvTag, Spec, ApplicableKernel, Name) is fact.
%
tag_db(0x4F,   _, 'b5..16', "Application Identifier (AID) – Card").
tag_db(0x50,   _, 'b1..16', "Application Label").
tag_db(0x57,   _, 'b...19', "Track 2 Equivalent Data").
tag_db(0x5A,   _, 'cn...19', "Application Primary Account Number (PAN)").
tag_db(0x5F20, _, 'ans2..26', "Cardholder Name").
tag_db(0x5F24, _, 'n6', "Application Expiration Date").
tag_db(0x5F25, _, 'n6', "Application Effective Date").
tag_db(0x5F2A, _, 'n3', "Transaction Currency Code").
tag_db(0x5F30, _, 'n3..4', "Service Code").
tag_db(0x5F34, _, 'n2', "Application PAN Sequence Number").
tag_db(0x61,   _, 't', "Application Template").
tag_db(0x6F,   _, 't', "File Control Information (FCI)").
tag_db(0x77,   _, 't', "Response Message Template Format 2").
tag_db(0x82,   _, 'b1..6', "File descriptor").
tag_db(0x83,   _, 'b2', "File identifier").
tag_db(0x84,   _, 'b...16', "Dedicated File (DF) Name").
tag_db(0x87,   _, 'b1', "Application Priority Indicator").
tag_db(0x87,   _, 'b1', "Application Priority Indicator").
tag_db(0x8A,   _, 'an2', "Authorisation Response Code").
tag_db(0x8C,   _, 'b...252', "Card Risk Management DOL 1").
tag_db(0x8D,   _, 'b...252', "Card Risk Management DOL 2").
tag_db(0x8E,   _, 'b...252', "Cardholder Verification Method (CVM) List").
tag_db(0x95,   _, 'b5', "Terminal Verification Results (TVR)").
tag_db(0x9A,   _, 'n6', "Transaction Date").
tag_db(0x9C,   _, 'n2', "Transaction Type").
tag_db(0x9F02, _, 'n12', "Amount, Authorised (numeric)").
tag_db(0x9F03, _, 'n12', "Amount, Other (numeric)").
tag_db(0x9F07, _, 'b2', "Application Usage Control (AUC)").
tag_db(0x9F08, _, 'b2', "Application Version").
tag_db(0x9F0D, _, 'b5', "Issuer Action Code (IAC) - Default").
tag_db(0x9F0E, _, 'b5', "Issuer Action Code (IAC) - Denial").
tag_db(0x9F0F, _, 'b5', "Issuer Action Code (IAC) - Online").
tag_db(0x9F10, _, 'b...32', "Issuer Application Data").
tag_db(0x9F1A, _, 'n3', "Terminal Country Code").
tag_db(0x9F26, _, 'b8', "Application Cryptogram").
tag_db(0x9F27, _, 'b1', "Cryptogram Information Data").
tag_db(0x9F28, _, 'b2', "Contactless Application Capabilities Type").
tag_db(0x9F2A, _, 'b2', "Kernel Identifier").
tag_db(0x9F35, _, 'n2', "Terminal Type").
tag_db(0x9F36, _, 'b2', "Application Transaction Counter (ATC)").
tag_db(0x9F37, _, 'b4', "Unpredictable Number (UN)").
tag_db(0x9F38, _, 'b...64', "Processing Options DOL (PDOL)").
tag_db(0x9F42, _, 'n3', "Application Currency Code").
tag_db(0x9F5A, 4, 'b1..4', "Membership Product Identifier").
tag_db(0x9F5A, 3, 'b1..16', "Application Program Identifier").
tag_db(0x9F5B, 2, 'b...252', "Data Storage DOL (DSDOL)"). %      ''
tag_db(0x9F5B, 3, 'b...252', "Issuer Script Results").    % Max size is var.
tag_db(0x9F5B, 4, '-', "Product Membership Number").
tag_db(0x9F63, 2, 'b6', "Positions of UN and ATC in Track 1 (PUNATC) ").
tag_db(0x9F64, 2, 'b1', "Number of ATC digits (NATC) in Track 1").
tag_db(0x9F65, 2, 'b2', "Positions of CVC3 (PCVC3) in Track 2").
tag_db(0x9F66, 3, 'b4', "Terminal Transaction Qualifiers (TTQ)").
tag_db(0x9F6C, _, 'b2', "Card Transaction Qualifiers (CTQ)").
tag_db(0xA5,   _, 't', "FCI Proprietary Template").
tag_db(0xBF0C, _, 't', "FCI Issuer Discretionary Data").


nesting_applicability(0x6F, 0x84).
nesting_applicability(0x6F, 0xA5).
nesting_applicability(0xA5, 0x50).
nesting_applicability(0xA5, 0x9F38).
nesting_applicability(0xA5, 0xBF0C).
nesting_applicability(0xBF0C, 0x61).
nesting_applicability(0x61, 0x4F).
nesting_applicability(0x61, 0x50).
nesting_applicability(0x61, 0x87).
nesting_applicability(0x61, 0x9F5A).
nesting_applicability(0x77, 0x57).
nesting_applicability(0x77, 0x82).
nesting_applicability(0x77, 0x5F34).
nesting_applicability(0x77, 0x9F10).
nesting_applicability(0x77, 0x9F26).
nesting_applicability(0x77, 0x9F27).
nesting_applicability(0x77, 0x9F36).
nesting_applicability(0x77, 0x9F6C).

% Tests
db_consistent :- duplicates, ambiguous_type, ef_hosts_files, db_rules_consistent.
db_rules_consistent :- forall(clause(db_check(run,R),_), db_check(_,R)).
duplicates :- forall(ft(F, _), findall(X, ft(F,X), [_])).
ambiguous_type :- \+((ft(Fid, T1), ft(Fid, T2), T1 \= T2)).
ef_hosts_files :- \+((ft(Ef, ef), pc(Ef, _))).
%ef_has_dfname :- forall(fn(F, _), type(df, F)).
%

:- dynamic(db_check/2).

db_check(run, all_constructed_tags_are_templates) :-
    forall((tag_spec_db(T,_,S,_),bits(8,[_,_,1|_],T)), S == template).
db_check(run, all_primitive_tags_are_data_elements) :-
    forall((tag_spec_db(T,_,S,_),bits(8,[_,_,0|_],T)), S = element(_,_)).
db_check(run, all_templates_are_constructed) :-
    forall(tag_spec_db(T,_,template,_), ((E=8;E=16),bits(E,[_,_,1|_],T))).
db_check(run, all_data_elements_are_primitive) :-
    forall(tag_spec_db(T,_,element(_,_),_), ((E=8;E=16),bits(E,[_,_,0|_],T))).
db_check(run, every_tag_spec_is_parseable) :-
    forall(tag_db(T, K, _, N), (tag_spec_db(T, K, _, N) -> true; throw(error(tag(T),_)))).
db_check(run, only_templates_can_nest_other_elements) :-
    tag_db_kernel(K),
    forall(nesting_applicability(T,_), tag_spec_db(T,K,template,_)).
db_check(run, every_template_defines_nesting) :-
    tag_db_kernel(K),
    forall(tag_spec_db(T,K,template,_), nesting_applicability(T,_)).
db_check(run, none_of_the_non_templates_can_nest_other_elements) :-
    forall(tag_spec_db(T,_,element(_,_),_), ((\+nesting_applicability(T,_)) -> true; throw(error(tag(T),_)))).
db_check(skip, every_non_template_is_nested_somewhere) :-
    forall(tag_spec_db(T,_,element(_,_),_), nesting_applicability(_,T)).
db_check(run, sw_db_extended_terminates_on_the_most_generic_query) :-
    sw_db_extended(_,_,_), fail; true.
