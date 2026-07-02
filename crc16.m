function crc = crc16(data)
%CRC16 CRC-16/CCITT-FALSE compatible con proto_crc16 del ESP32.
%
% crc = crc16(data) calcula CRC con polinomio 0x1021, init 0xFFFF,
% sin reflexion y sin xor final. Devuelve uint16.

data = uint8(data);
crc = uint16(hex2dec('FFFF'));
poly = uint16(hex2dec('1021'));

for i = 1:numel(data)
    crc = bitxor(crc, bitshift(uint16(data(i)), 8));
    for b = 1:8
        if bitand(crc, uint16(hex2dec('8000')))
            crc = bitxor(bitshift(crc, 1), poly);
        else
            crc = bitshift(crc, 1);
        end
        crc = bitand(crc, uint16(hex2dec('FFFF')));
    end
end
end
