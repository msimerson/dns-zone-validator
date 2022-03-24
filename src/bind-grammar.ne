# This is a parser, not a validator. Don't go crazy with rules here,
# we validate after parsing

@builtin "string.ne"

main            -> (statement eol):+

statement       -> blank | ttl | origin | soa | ns | mx | a | txt | aaaa | cname | dname | ptr

eol             -> "\n" | "\r"

blank           -> _

comment         -> ";" [^\n\r]:*

ttl             -> "$TTL" __ uint _ (comment):? _           {% asTTL %}

origin          -> "$ORIGIN" __ hostname _ (comment):? _    {% asOrigin %}

soa             -> hostname ( __ uint ):? ( __ class ):? __ "SOA"
                   __ hostname __ hostname __ "("
                     _ uint (ws comment):?
                     __ uint (ws comment):?
                     __ uint (ws comment):?
                     __ uint (ws comment):?
                     __ uint (ws comment):?
                   _ ")" _ (comment):?                       {% asRR %}

ns              -> hostname (__ uint):? (__ class):? __ "NS"
                   __ hostname _ (comment):? _               {% asRR %}

mx              -> hostname (__ uint):? (__ class):? __ "MX"
                   __ uint __ hostname _ (comment):?         {% asRR %}

a               -> hostname (__ uint):? (__ class):? __ "A"
                   __ ip4 _ (comment):? _                    {% asRR %}

txt             -> hostname (__ uint):? (__ class):? __ "TXT"
                   __ (dqstring _):+ (comment):? _           {% asRR %}

aaaa            -> hostname (__ uint):? (__ class):? __ "AAAA"
                   __ ip6 _ (comment):? _                    {% asRR %}

cname           -> hostname (__ uint):? (__ class):? __ "CNAME"
                   __ hostname _ (comment):? _               {% asRR %}

dname           -> hostname (__ uint):? (__ class):? __ "DNAME"
                   __ hostname _ (comment):? _               {% asRR %}

ptr             -> hostname (__ uint):? (__ class):? __ "PTR"
                   __ hostname _ (comment):? _               {% asRR %}

uint            -> [0-9]:+ {% (d) => parseInt(d[0].join("")) %}

hostname        -> ALPHA_NUM_DASH_U:* {% (d) => d[0].join("") %}

ALPHA_NUM_DASH_U -> [0-9A-Za-z\u0080-\uFFFF\.\-_@] {% id %}

class           -> "IN" | "CS" | "CH" | "HS" | "NONE" | "ANY"

#not_whitespace  -> [^\n\r] {% id %}
#host_chars      -> [-0-9A-Za-z\u0080-\uFFFF._@/] {% id %}

times_3[X]      -> $X $X $X
times_5[X]      -> $X $X $X $X $X
times_7[X]      -> $X $X $X $X $X $X $X

ip4             -> int8 times_3["."  int8]   {% flatten %}

ip6             -> ip6_full | ip6_compressed | IPv6v4_full | IPv6v4_comp

int8            -> DIGIT |
                   [1-9] DIGIT |
                   "1" DIGIT DIGIT |
                   "2" [0-4] DIGIT |
                   "25" [0-5]

DIGIT          -> [0-9] {% id %}
HEXDIG         -> [0-9A-Fa-f] {% id %}

IPv6_hex       -> HEXDIG |
                  HEXDIG HEXDIG |
                  HEXDIG HEXDIG HEXDIG |
                  HEXDIG HEXDIG HEXDIG HEXDIG

ip6_full       -> IPv6_hex times_7[":" IPv6_hex] {% flatten %}

ip6_compressed -> "::"                           {% flatten %} |
                  "::" IPv6_hex                  {% flatten %} |
                  IPv6_hex (":" IPv6_hex):* "::" IPv6_hex (":" IPv6_hex):* {% flatten %}

IPv6v4_full    -> IPv6_hex times_5[":" IPv6_hex] ":" ip4                   {% flatten %}

IPv6v4_comp    -> (IPv6_hex times_3[":" IPv6_hex]):? "::"
                  (IPv6_hex times_3[":" IPv6_hex] ":"):? ip4               {% flatten %}

# Whitespace: `_` is optional, `__` is mandatory.
_  -> wschar:* {% function(d) {return null;} %}
__ -> wschar:+ {% function(d) {return null;} %}
ws -> wschar:* {% id %}

wschar -> [ \t\n\r\v\f] {% id %}

@{%
function flatten (d) {
  if (!d) return ''
  if (Array.isArray(d)) return d.flat(Infinity).join('')
  return d
}

function asTTL (d) {
  return { $TTL: d[2] }
}

function asOrigin (d) {
  return { $ORIGIN: d[2] }
}

function asRR (d) {
  const r = {
    name:  d[0],
    ttl :  d[1] ? d[1][1]    : d[1],
    class: d[2] ? d[2][1][0] : d[2],
    type:  d[4],
  }

  switch (r.type) {
    case 'A':
      r.address = d[6]
      break
    case 'AAAA':
      r.address = d[6][0]
      break
    case 'CNAME':
      r.cname = d[6]
      break
    case 'DNAME':
      r.target = d[6]
      break
    case 'MX':
      r.preference = d[6]
      r.exchange  = d[8]
      break
    case 'NS':
      r.dname = d[6]
      break
    case 'PTR':
      r.dname = d[6]
      break
    case 'SOA':
      r.comment = {}
      r.mname   = d[6]
      r.rname   = d[8]
      r.serial  = d[12]
      r.comment.serial = flatten(d[13])
      r.refresh = d[15]
      r.comment.refresh = flatten(d[16])
      r.retry   = d[18]
      r.comment.retry = flatten(d[19])
      r.expire  = d[21]
      r.comment.expire = flatten(d[22])
      r.minimum = d[24]
      r.comment.minimum = flatten(d[25])
      break
    case 'TXT':
      r.data = d[6].map(e => e[0])
      break
    default:
      throw new Error(`undefined type: ${r.type}`)
  }
  return r
}

%}
