pragma solidity >=0.6.0;

library MoreAssert {

    uint8 constant ZERO = uint8(byte('0'));
    uint8 constant A = uint8(byte('a'));

    function equal(uint a, uint b, uint base, string memory message)
        internal pure returns (bool result) {
        
        if (a == b) return true;
        uint diff = (a > b) ? (a - b) : (b - a);
        result = (a > b) ? (a / diff > base) : (b / diff > base);
        if (!result) {
             revert(_appendTagged(_tag(a, "Tested"), _tag(b, "Against"), message));
        }
    }

    function _appendTagged(string memory tagged0, string memory tagged1, string memory str)
        internal pure returns (string memory) {

        bytes memory tagged0B = bytes(tagged0);
        bytes memory tagged1B = bytes(tagged1);
        bytes memory strB = bytes(str);

        uint sl = strB.length;
        uint t0l = tagged0B.length;
        uint t1l = tagged1B.length;

        bytes memory newB = new bytes(sl + t0l + t1l + 5);

        uint i;
        uint j;

        for (i = 0; i < sl; i++)
            newB[j++] = strB[i];
        newB[j++] = ' ';
        newB[j++] = '(';
        for (i = 0; i < t0l; i++)
            newB[j++] = tagged0B[i];
        newB[j++] = ',';
        newB[j++] = ' ';
        for (i = 0; i < t1l; i++)
            newB[j++] = tagged1B[i];
        newB[j++] = ')';

        return string(newB);
    }

    function _tag(uint value, string memory tag) internal pure returns (string memory) {
        string memory nstr = _utoa(value, 10);
        return _tag(nstr, tag);
    }

    function _tag(string memory value, string memory tag) internal pure returns (string memory) {

        bytes memory valueB = bytes(value);
        bytes memory tagB = bytes(tag);

        uint vl = valueB.length;
        uint tl = tagB.length;

        bytes memory newB = new bytes(vl + tl + 2);

        uint i;
        uint j;

        for (i = 0; i < tl; i++)
            newB[j++] = tagB[i];
        newB[j++] = ':';
        newB[j++] = ' ';
        for (i = 0; i < vl; i++)
            newB[j++] = valueB[i];

        return string(newB);
    }

    function _utoa(uint n, uint8 radix) internal pure returns (string memory) {
        if (n == 0 || radix < 2 || radix > 16)
            return '0';
        bytes memory bts = new bytes(256);
        uint i;
        while (n > 0) {
            bts[i++] = _utoa(uint8(n % radix)); // Turn it to ascii.
            n /= radix;
        }
        // Reverse
        bytes memory rev = new bytes(i);
        for (uint j = 0; j < i; j++)
            rev[j] = bts[i - j - 1];
        return string(rev);
    }

    function _utoa(uint8 u) internal pure returns (byte) {
        if (u < 10)
            return byte(u + ZERO);
        else if (u < 16)
            return byte(u - 10 + A);
        else
            return 0;
    }
}