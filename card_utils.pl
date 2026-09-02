:- initialization(testall(cardut)).

dol(_, []) --> [].
dol(Kernel, [Tag|Tags]) -->
    {
        tag_properties(Tag, Kernel, [requested_size(S)]),
        once(bytes(_, Bytes, Tag))
    },
    Bytes, [S], dol(Kernel, Tags).

% EMV Book 3 table CCD 3
cryptogram_information_data([0,0,0,0,0,0,0,0], aac).
cryptogram_information_data([0,1,0,0,0,0,0,0], tc).
cryptogram_information_data([1,0,0,0,0,0,0,0], arqc).

% EMV Book C-3 pp 91-92
ctq(Qualifiers, Bytes) :-
    Q1 = [online_pin_required,signature_required,go_online_if_oda_fails_and_reader_is_online_capable,
          switch_interface_if_oda_fails,go_online_if_application_expired,
          switch_interface_for_cash,switch_interface_for_cashback,false],
    Q2 = [cdcvm_performed,card_supports_issuer_update_processing_at_the_pos,
          false, false,false,false,false,false],
    maplist(qual(Qualifiers), Q1, B1),
    maplist(qual(Qualifiers), Q2, B2),
    maplist(bits(8), [B1,B2], Bytes).

qual(Qualifiers, Name, Bit) :- Name \= false, member(Name, Qualifiers) -> Bit = 1; Bit = 0.

% https://sdk.supply/comparison-of-emv-compatible-applications
% 9F10
%                        06 01   0A   03 90   00   00 // CDET
visa_discretionary_data([B1,B2,0x11,0x03,B5,0x00,0x00]) :-
    cryptogram_version_number(B1),
    derivation_key_indicator(B2),
    phrase(cvr_1, Bits),
    bits(8, Bits, B5).

%% cvr_1(A, B, C, D, E, F).
%
% @source https://paymentcardtools.com/emv-tag-decoders/iad
% C = 1 when Issuer Authentication performed and failed
% D = 1 when Offline PIN verification performed
% E = 1 when Offline PIN verification failed
% F = 1 when Unable to go online
%
% All of them must be 0 otherwise
%
% @source EMB Book 3 section C7.3
%
cvr_1 -->
    { cvr(A, B, C, D, E, F) },
    cvr_second_generate_ac(A), cvr_first_generate_ac(B), bit(C), bit(D), { D = 0 -> E = 0; D = 1 }, bit(E), bit(F).

% Application Cryptogram Type Returned in 2nd GENERATE AC
cvr_second_generate_ac(aac) --> [0,0].
cvr_second_generate_ac(tc) --> [0,1].
% 2nd GENERATE AC not requested
cvr_second_generate_ac(not_requested) --> [1,0].

% Application Cryptogram Type returned in 1st GENERATE AC
cvr_first_generate_ac(aac) --> [0,0].
cvr_first_generate_ac(tc) --> [0,1].
cvr_first_generate_ac(arqc) --> [1,0].

bit(1) --> [1].
bit(0) --> [0].
