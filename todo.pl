% https://sdk.supply/the-standard-of-emv-entry-point-specification/
% 9F28
contactless_application_capabilities(EmvApplicationPresent, NativeApplicationPresent, ProcessingPreferenceIndicator, TerminalApplication, [B1,B2]) :-
    phrase(contactless_application_capabilities_1(EmvApplicationPresent, NativeApplicationPresent, ProcessingPreferenceIndicator), Bits1),
    phrase(contactless_application_capabilities_2(TerminalApplication), Bits2),
    maplist(bits(8), [Bits1,Bits2], [B1,B2]).
contactless_application_capabilities_1(EmvApplicationPresent, NativeApplicationPresent, ProcessingPreferenceIndicator) -->
    bit(EmvApplicationPresent), bit(NativeApplicationPresent), bit(ProcessingPreferenceIndicator), [0,0,0,0,0].
% Name of the terminal application associated with this application
contactless_application_capabilities_2(native_jcb) --> [0,0,0,0,0,0,0,1].
contactless_application_capabilities_2(mastercard_paypass) --> [0,0,0,0,0,0,1,0].
contactless_application_capabilities_2(visa_contactless) --> [0,0,0,0,0,0,1,1].
contactless_application_capabilities_2(numeric(N)) --> [A,B,C,D,E,F,G,H], { bits(8, [A,B,C,D,E,F,G,H], N), N > 3, N < 255 }.
