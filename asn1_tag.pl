tag_property_asn(Int, Class, PC, Numeric) :-
    pow2_required_digits(8, Int, NumberOfBytes),
    bits(8*NumberOfBytes, [A,B,C|Rest], Int),
    tag_pc(C, PC),
    phrase(tag_bits(Bits), Rest),
    once(bits(_, Bits, Numeric)), % FIXME: Remove once/1
    tag_class(A, B, Class).

tag_bits(Bits) --> [1,1,1,1,1], tag_bits_long(Bits).
tag_bits(Bits) --> [A,B,C,D,E], { Bits = [A,B,C,D,E], bits(5, Bits, N), N < 0b11111 }.

tag_bits_long([B2,B3,B4,B5,B6,B7,B8]) --> [0,B2,B3,B4,B5,B6,B7,B8].
tag_bits_long([B2,B3,B4,B5,B6,B7,B8|R]) --> [1,B2,B3,B4,B5,B6,B7,B8], tag_bits_long(R).

tag_class(0, 0, universal).
tag_class(0, 1, application).
tag_class(1, 0, context_specific).
tag_class(1, 1, private).

tag_pc(0, primitive).
tag_pc(1, constructed).

tag_universal(01, primitive, 'BOOLEAN').
tag_universal(02, primitive, 'INTEGER').
tag_universal(03, primitive, 'BIT STRING').
tag_universal(04, primitive, 'OCTET STRING').
tag_universal(05, primitive, 'NULL').
tag_universal(06, primitive, 'OBJECT IDENTIFIER').
tag_universal(09, primitive, 'REAL').
tag_universal(10, primitive, 'ENUMERATED').
tag_universal(11, primitive, 'EMBEDDED PDV').
tag_universal(16, constructed, 'SEQUENCE').
tag_universal(16, constructed, 'SEQUENCE OF').
tag_universal(17, constructed, 'SET').
tag_universal(17, constructed, 'SET OF').
%tag_universal(_, constructed, 'CHOICE') :- false.
tag_universal(07, primitive, 'ObjectDescriptor').
tag_universal(13, primitive, 'RELATIVE-OID').
tag_universal(08, primitive, 'EXTERNAL').
tag_universal(12, primitive, 'UTF8String').
tag_universal(18, primitive, 'NumericString').
tag_universal(19, primitive, 'PrintableString').
tag_universal(20, primitive, 'TeletexString').
tag_universal(20, primitive, 'T61String').
tag_universal(21, primitive, 'VideotexString').
tag_universal(22, primitive, 'IA5String').
tag_universal(25, primitive, 'GraphicString').
tag_universal(26, primitive, 'VisibleString').
tag_universal(27, primitive, 'GeneralString').
tag_universal(28, primitive, 'UniversalString').
tag_universal(29, primitive, 'CHARACTER STRING').
tag_universal(30, primitive, 'BMPString').
tag_universal(14, primitive, 'TIME').
tag_universal(23, primitive, 'UTCTime').
tag_universal(24, primitive, 'GeneralizedTime').
tag_universal(31, primitive, 'DATE').
tag_universal(32, primitive, 'TIME-OF-DAY').
tag_universal(33, primitive, 'DATE-TIME').
tag_universal(34, primitive, 'DURATION').
