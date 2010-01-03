// ==UserScript==
// @name           BarcodeSelected
// @namespace      yetanotherdomain.org
// @description    Convert highlighted text into a barcode image
// @include        *
// @exclude        
// ==/UserScript==

function Code39(strDataToEncode, blnAddCheckDigit){
    var ary3of9CharSet = new Array(43);
    var strChar = "";
    var lngCheckDigit = 0;
    var lngCharIndex = 0;
    var strEncode = "";
    var strEncodeFormat = "";
    var i = 0;
    var j = 0;
    var reg = new RegExp("[a-zA-Z0-9\-._\$\/+\%]");
    var cstrGuard = "010010100";
    var cstrPadd = "0";
    var strEncodedString = "";
    // numbers 0 to 9
    ary3of9CharSet[0] = "000110100";
    ary3of9CharSet[1] = "100100001";
    ary3of9CharSet[2] = "001100001";
    ary3of9CharSet[3] = "101100000";
    ary3of9CharSet[4] = "000110001";
    ary3of9CharSet[5] = "100110000";
    ary3of9CharSet[6] = "001110000";
    ary3of9CharSet[7] = "000100101";
    ary3of9CharSet[8] = "100100100";
    ary3of9CharSet[9] = "001100100";
    // letters A to Z
    ary3of9CharSet[10] = "100001001";
    ary3of9CharSet[11] = "001001001";
    ary3of9CharSet[12] = "101001000";
    ary3of9CharSet[13] = "000011001";
    ary3of9CharSet[14] = "100011000";
    ary3of9CharSet[15] = "001011000";
    ary3of9CharSet[16] = "000001101";
    ary3of9CharSet[17] = "100001100";
    ary3of9CharSet[18] = "001001100";
    ary3of9CharSet[19] = "000011100";
    ary3of9CharSet[20] = "100000011";
    ary3of9CharSet[21] = "001000011";
    ary3of9CharSet[22] = "101000010";
    ary3of9CharSet[23] = "000010011";
    ary3of9CharSet[24] = "100010010";
    ary3of9CharSet[25] = "001010010";
    ary3of9CharSet[26] = "000000111";
    ary3of9CharSet[27] = "100000110";
    ary3of9CharSet[28] = "001000110";
    ary3of9CharSet[29] = "000010110";
    ary3of9CharSet[30] = "110000001";
    ary3of9CharSet[31] = "011000001";
    ary3of9CharSet[32] = "111000000";
    ary3of9CharSet[33] = "010010001";
    ary3of9CharSet[34] = "110010000";
    ary3of9CharSet[35] = "011010000";
    // allowed symbols - . _ $ / + %
    ary3of9CharSet[36] = "010000101";
    ary3of9CharSet[37] = "110000100";
    ary3of9CharSet[38] = "011000100";
    ary3of9CharSet[39] = "010101000";
    ary3of9CharSet[40] = "010100010";
    ary3of9CharSet[41] = "010001010";
    ary3of9CharSet[42] = "000101010";
    // validate data to encode
    // replace spaces w/ underscores
    // remove all asterisks * (we will add them later)
    // force upper case per spec
    while (strDataToEncode.indexOf(" ") != -1) strDataToEncode = strDataToEncode.replace(" ", "_");
    while (strDataToEncode.indexOf("*") != -1) strDataToEncode = strDataToEncode.replace("*", "");
    strDataToEncode = strDataToEncode.toUpperCase();
    // encode data using character set
    // get the check digit calculation while we're at it


        for (i = 0; i < strDataToEncode.length; i++){
        strChar = strDataToEncode.substr(i, 1);


            if (!reg.test(strChar)){
            alert("Invalid Character Specified!");
            return "";
        }


            switch (true){
            case strChar == "-": lngCharIndex = 36; break;
            case strChar == ".": lngCharIndex = 37; break;
            case strChar == "_": lngCharIndex = 38; break;
            case strChar == "$": lngCharIndex = 39; break;
            case strChar == "/": lngCharIndex = 40; break;
            case strChar == "+": lngCharIndex = 41; break;
            case strChar == "%": lngCharIndex = 42; break;
            case !isNaN(strChar): lngCharIndex = eval(strChar); break;
            default: lngCharIndex = strChar.charCodeAt(0) - 55; break;
        }
        lngCheckDigit += lngCharIndex;
        strEncode += ary3of9CharSet[lngCharIndex];
    }
    // finish the check-digit
    lngCheckDigit %= 43;
    // should we incorporate the check digit?
    if (blnAddCheckDigit != 0) strEncode += ary3of9CharSet[lngCheckDigit];
    // add start/stop characters (asterisks "*")
    strEncode = cstrGuard + strEncode + cstrGuard;
    // now, format the output - the std aspect ratio is 3:1 per spec (used here)
    //- the minimum ratio is 2:1 fyi.
    // hint -- the odd/even value of the variable "j" (found by "or-ing" by 1)
    // indicates whether a bar or space should be produced. the value (1 or 0) found
    // in the string variable "strEncodeFormat" at the location of "j" indicates
    // whether the bar/space should be a wide or narrow element in the bar code.


        for (i = 0; i < strEncode.length; i += 9){
        strEncodeFormat = strEncode.substr(i, 9);


            for (j = 0; j < 9; j++){


                if ((j & 1) == 1){
                strEncodedString += ((strEncodeFormat.substr(j, 1) == 1) ? "000" : "0");
            }else{
            strEncodedString += ((strEncodeFormat.substr(j, 1) == 1) ? "111" : "1");
        }
    }
    strEncodedString += cstrPadd;
}
return strEncodedString;
}


function makeOnBit () {
    var bit = document.createElement("div");
    //bit.className='bitOn';
    bit.style.cssFloat = 'left';
    bit.style.height = '92%';
    bit.style.width = 0;
    bit.style.borderLeft = '.15em solid black';
    bit.style.backgroundColor = '#000000';

    return bit;
}

function makeOffBit () {
    var bit = document.createElement("div");
    //bit.className = 'bitOff';
    bit.style.cssFloat = 'left';
    bit.style.height = '92%';
    bit.style.width = '.15em';
    bit.style.backgroundColor = '#FFFFFF';
    return bit;
}


function makeQuietZone () {
    var quietZone = document.createElement("div");
    //quietZone.className = 'quietZone';
    quietZone.style.cssFloat = 'left';
    quietZone.style.height = '92%';
    var i;
    for (i = 0; i < 9; i++) {
        quietZone.appendChild(makeOffBit());
    }

    return quietZone;
}

function MakeBarcode(code) {
    var bitstring = Code39(code, 0);

    var barcode = document.createElement("div");
    //barcode.className = 'barcode';
    barcode.style.color = 'black';
    barcode.style.backgroundColor = 'white';
    barcode.style.position = 'relative';
    barcode.style.left = 0;
    barcode.style.top = '1em';
    barcode.style.height = '12em';
    barcode.style.cssFloat = 'left';
    barcode.style.clear = 'left';
    barcode.style.fontSize = '.75em';
    barcode.style.marginRight = '1em';

    // label
    var descDiv = document.createElement("div");
    descDiv.innerHTML = 'Order number';
    barcode.appendChild(descDiv);

    //quiet zone
    barcode.appendChild(makeQuietZone());

    //leader
    var leader = document.createElement("div");
    //leader.className = 'leader';
    leader.style.cssFloat = 'left';
    leader.style.height = '92%';
    leader.appendChild(makeOnBit());
    leader.appendChild(makeOffBit());
    leader.appendChild(makeOnBit());
    barcode.appendChild(leader);

    //now the digits
    var digits = document.createElement("div");
    //digits.className = 'digit';
    digits.style.cssFloat = 'left';
    digits.style.height = '80%';
    var currentBit;
    for (currentBit = 0; currentBit < bitstring.length; currentBit++) {
        var bit = eval(bitstring.substr(currentBit, 1));

        digits.appendChild((bit == 1) ? makeOnBit() : makeOffBit());
    }
    barcode.appendChild(digits);

    var trailer = document.createElement("div");
    leader.appendChild(makeOnBit());
    leader.appendChild(makeOffBit());
    leader.appendChild(makeOnBit());
    barcode.appendChild(trailer);

    // another quiet zone
    barcode.appendChild(makeQuietZone());

    var codeDiv = document.createElement("div");
    codeDiv.innerHTML = code;
    codeDiv.style.fontFamily = 'Courrier New';
    codeDiv.style.fontSize = '1.3em';
    codeDiv.style.position = 'absolute';
    codeDiv.style.color = 'black';
    codeDiv.style.backgroundColor = 'white';
    codeDiv.style.top = '85%';
    codeDiv.style.left = '16%';
    codeDiv.style.margin = '0';
    codeDiv.style.marginLeft = 'auto';
    codeDiv.style.marginRight = 'auto';
    codeDiv.style.padding = '0';
    codeDiv.style.textAlign = 'center';
    barcode.appendChild(codeDiv);

    return barcode;
}


document.addEventListener('mouseup',
    function () {

        var sel = '';
        GM_log('Looking for highlighted text');

        if (window.getSelection) {
            sel = window.getSelection();

        } else if (document.getSelection) {
            sel = document.getSelection();

        } else if (document.selection) {
            sel = document.selection.createRange().text;

        } else return;

        if (! sel) {
            GM_log('no selection?');
            return;
        }

        var txt = sel.toString ? sel.toString() : sel;

        if (! txt.length) {
            GM_log('length was zero');
            return;
        }

        GM_log('length was non-zero!');

        var barcodeDiv = MakeBarcode(txt);
        document.body.appendChild(barcodeDiv);
        barcodeDiv.style.display = '';

        barcodeDiv.addEventListener('click',
            function () {
                document.body.removeChild(barcodeDiv);
                barcodeDiv.style.display = 'none';
                barcodeDiv = null;
            },
            true);
 
    },
    true);


