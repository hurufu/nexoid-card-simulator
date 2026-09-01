%% EMV tag database %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
:- initialization(testall(tag_db)).

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
%
% TODO: Some sub-formats that are not formally introduced in the documentation aren't supported:
%         * array notation: 1..4 an8
%         * fake templates (implicit sequence): s22
%         * null padded ASCII strings: zan
%
% TODO: Type algebra: an2..8 + b3..9 = b9, n12 + n3 = n15. It can be useful to
%       verify sequence type based on type of its constituents.
%
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
tag_db(0x5F2D, _, 'an2..8', "Language Preference"). % Alternative type would be '1..4 an2'
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
tag_db(0xDF8116, 2, 'b22', "User Interface Request Data"). % Alternative type would be 's22' or 's'
% FIXME: Decide how and if I should encode fake templates.
%tag_db(sequence(0xDF8116), 2, 'b1', "Message Identifier").
%tag_db(sequence(0xDF8116), 2, 'b1', "Status").
%tag_db(sequence(0xDF8116), 2, 'n6', "Hold Time").
%tag_db(sequence(0xDF8116), 2, 'an8', "Language Preference"). % Alternative type would be '4 zan2'
%tag_db(sequence(0xDF8116), 2, '1b', "Value Qualifier").
%tag_db(sequence(0xDF8116), 2, 'n12', "Value").
%tag_db(sequence(0xDF8116), 2, 'n3', "Currency Code").

nesting_applicability(0x61, 0x4F).
nesting_applicability(0x61, 0x50).
nesting_applicability(0x61, 0x87).
nesting_applicability(0x61, 0x9F5A).
nesting_applicability(0x6F, 0x84).
nesting_applicability(0x6F, 0xA5).
nesting_applicability(0x77, 0x57).
nesting_applicability(0x77, 0x5F34).
nesting_applicability(0x77, 0x82).
nesting_applicability(0x77, 0x9F10).
nesting_applicability(0x77, 0x9F26).
nesting_applicability(0x77, 0x9F27).
nesting_applicability(0x77, 0x9F36).
nesting_applicability(0x77, 0x9F6C).
nesting_applicability(0xA5, 0x50).
nesting_applicability(0xA5, 0x9F38).
nesting_applicability(0xA5, 0xBF0C).
nesting_applicability(0xBF0C, 0x61).
%nesting_applicability(0xDF8116, sequence(0xDF8116)).

% Tests
t(tag_db, true, (all_constructed_tags_are_templates :-
    forall(
        (
            tag_spec_db(T,_,S,_),
            bits(8,[_,_,1|_],T)
        ),
        S == template
    )
)).
t(tag_db, true, (all_primitive_tags_are_data_elements :-
    forall(
        (
            tag_spec_db(T,_,S,_),
            bits(8,[_,_,0|_],T)
        ),
        S = element(_,_)
    )
)).
t(tag_db, true, (all_templates_are_constructed :-
    forall(
        tag_spec_db(T,_,template,_),
        (
            (E=8; E=16; E=24; E=32),
            bits(E,[_,_,1|_],T)
        )
    )
)).
t(tag_db, true, (all_data_elements_are_primitive :-
    forall(
        tag_spec_db(T,_,element(_,_),_),
        (
            (E=8; E=16; E=24; E=32),
            bits(E,[_,_,0|_],T)
        )
    )
)).
t(tag_db, true, ('Every tag spec is parseable' :-
    forall(tag_db(T,K,_,N), (tag_spec_db(T,K,_,N)->true;throw(error(tag(T),_))))
)).
t(tag_db, true, ('Only templates can nest other elements' :-
    forall(nesting_applicability(T,_), tag_spec_db(T,3,template,_))
)).
t(tag_db, true, ('Every template defines nesting' :-
    forall(tag_spec_db(T,4,template,_), nesting_applicability(T,_))
)).
t(tag_db, true, ('None of the non templates can nest other elements' :-
    forall(tag_spec_db(T,_,element(_,_),_), (\+nesting_applicability(T,_)->true;throw(error(tag(T),_))))
)).
t(tag_db, skip, ('Every non-template is nested somewhere' :-
    forall(tag_spec_db(T,_,element(_,_),_), nesting_applicability(_,T))
)).
t(tag_db, false, ('All format specifiers are enumerable' :-
    phrase(fmt(_), _), fail
)).
