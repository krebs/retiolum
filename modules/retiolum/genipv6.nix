# stolen from krebs/stockholm
{ lib ? (import <nixpkgs> {}).lib }:
with lib;
let {
  body = netname: subnetname: suffixSpec: rec {
    address = let
      suffix' = prependZeros suffixLength suffix;
    in
      normalize-ip6-addr
        (checkAddress addressLength (joinAddress subnetPrefix suffix'));
    addressCIDR = "${address}/${toString addressLength}";
    addressLength = 128;

    inherit netname;
    netCIDR = "${netAddress}/${toString netPrefixLength}";
    netAddress =
      normalize-ip6-addr (appendZeros addressLength netPrefix);
    netHash = toString {
      retiolum = 0;
      wiregrill = 1;
    }.${netname};
    netPrefix = "42:${netHash}";
    netPrefixLength = {
      retiolum = 32;
      wiregrill = 32;
    }.${netname};

    inherit subnetname;
    subnetCIDR = "${subnetAddress}/${toString subnetPrefixLength}";
    subnetAddress =
      normalize-ip6-addr (appendZeros addressLength subnetPrefix);
    subnetHash = hashToLength 4 subnetname;
    subnetPrefix = joinAddress netPrefix subnetHash;
    subnetPrefixLength = netPrefixLength + 16;

    suffix = getAttr (builtins.typeOf suffixSpec) {
      set =
        concatStringsSep
          ":"
          (stringToGroupsOf
            4
            (hashToLength (suffixLength / 4) suffixSpec.hostName));
      string = suffixSpec;
    };
    suffixLength = addressLength - subnetPrefixLength;
  };

  appendZeros = n: s: let
    n' = n / 16;
    zeroCount = n' - length parsedaddr;
    parsedaddr = parseAddress s;
  in
    formatAddress (parsedaddr ++ map (const "0") (range 1 zeroCount));

  prependZeros = n: s: let
    n' = n / 16;
    zeroCount = n' - length parsedaddr;
    parsedaddr = parseAddress s;
  in
    formatAddress (map (const "0") (range 1 zeroCount) ++ parsedaddr);

  hasEmptyPrefix = xs: take 2 xs == ["" ""];
  hasEmptySuffix = xs: takeLast 2 xs == ["" ""];
  hasEmptyInfix = xs: any (x: x == "") (trimEmpty 2 xs);

  hasEmptyGroup = xs:
    any (p: p xs) [hasEmptyPrefix hasEmptyInfix hasEmptySuffix];

  hashToLength = n: s: substring 0 n (builtins.hashString "sha256" s);

  ltrimEmpty = n: xs: if hasEmptyPrefix xs then drop n xs else xs;
  rtrimEmpty = n: xs: if hasEmptySuffix xs then dropLast n xs else xs;
  trimEmpty = n: xs: rtrimEmpty n (ltrimEmpty n xs);

  parseAddress = splitString ":";
  formatAddress = concatStringsSep ":";

  check = s: c: if !c then throw "${s}" else true;

  checkAddress = maxaddrlen: addr: let
    parsedaddr = parseAddress addr;
    normalizedaddr = trimEmpty 1 parsedaddr;
  in
    assert (check "address malformed; lone leading colon: ${addr}" (
      head parsedaddr == "" -> tail (take 2 parsedaddr) == ""
    ));
    assert (check "address malformed; lone trailing colon ${addr}" (
      last parsedaddr == "" -> head (takeLast 2 parsedaddr) == ""
    ));
    assert (check "address malformed; too many successive colons: ${addr}" (
      length (filter (x: x == "") normalizedaddr) > 1 -> addr == [""]
    ));
    assert (check "address malformed: ${addr}" (
      all (test "[0-9a-f]{0,4}") parsedaddr
    ));
    assert (check "address is too long: ${addr}" (
      length normalizedaddr * 16 <= maxaddrlen
    ));
    addr;

  joinAddress = prefix: suffix: let
    parsedPrefix = parseAddress prefix;
    parsedSuffix = parseAddress suffix;
    normalizePrefix = rtrimEmpty 2 parsedPrefix;
    normalizeSuffix = ltrimEmpty 2 parsedSuffix;
    delimiter =
      optional (length (normalizePrefix ++ normalizeSuffix) < 8 &&
                (hasEmptySuffix parsedPrefix || hasEmptyPrefix parsedSuffix))
               "";
  in
    formatAddress (normalizePrefix ++ delimiter ++ normalizeSuffix);

  # https://tools.ietf.org/html/rfc5952
  normalize-ip6-addr =
    let
      max-run-0 =
        let
          both = v: { off = v; pos = v; };
          gt = a: b: a.pos - a.off > b.pos - b.off;

          chkmax = ctx: {
            cur = both (ctx.cur.pos + 1);
            max = if gt ctx.cur ctx.max then ctx.cur else ctx.max;
          };

          incpos = ctx: recursiveUpdate ctx {
            cur.pos = ctx.cur.pos + 1;
          };

          f = ctx: blk: (if blk == "0" then incpos else chkmax) ctx;
          z = { cur = both 0; max = both 0; };
        in
          blks: (chkmax (foldl' f z blks)).max;

      group-zeros = a:
        let
          blks = splitString ":" a;
          max = max-run-0 blks;
          lhs = take max.off blks;
          rhs = drop max.pos blks;
        in
          if max.pos == 0
            then a
            else let
              sep =
                if 8 - (length lhs + length rhs) == 1
                  then ":0:"
                  else "::";
            in
              "${concatStringsSep ":" lhs}${sep}${concatStringsSep ":" rhs}";

      drop-leading-zeros =
        let
          f = block:
            let
              res = builtins.match "0*(.+)" block;
            in
              if res == null
                then block # empty block
                else elemAt res 0;
        in
          a: concatStringsSep ":" (map f (splitString ":" a));
    in
      a:
        toLower
          (if test ".*::.*" a
            then a
            else group-zeros (drop-leading-zeros a));

  # Split string into list of chunks where each chunk is at most n chars long.
  # The leftmost chunk might shorter.
  # Example: stringToGroupsOf "123456" -> ["12" "3456"]
  stringToGroupsOf = n: s: let
    acc =
      foldl'
        (acc: c: if stringLength acc.chunk < n then {
          chunk = acc.chunk + c;
          chunks = acc.chunks;
        } else {
          chunk = c;
          chunks = acc.chunks ++ [acc.chunk];
        })
        {
          chunk = "";
          chunks = [];
        }
        (stringToCharacters s);
  in
    filter (x: x != []) ([acc.chunk] ++ acc.chunks);


  takeLast = n: xs: reverseList (take n (reverseList xs));

  test = re: x: isString x && testString re x;

  testString = re: x: builtins.match re x != null;

}
