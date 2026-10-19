"""Copy original Spanish Gold text by paired map/script identity, never address proximity."""
import argparse
from collections import Counter, deque
import hashlib
import math
import importlib.util
import sys
import json
from pathlib import Path
import re
import subprocess
import tempfile
import struct
import zlib


def offset(bank, address):
    if bank == 0 and 0 <= address < 0x4000:
        return address
    if bank > 0 and 0x4000 <= address < 0x8000:
        return bank*0x4000+address-0x4000
    raise ValueError('invalid ROM address')


def byte(rom, bank, address):
    return rom[offset(bank,address)]


def word(rom, bank, address):
    return byte(rom,bank,address)+256*byte(rom,bank,address+1)


def instruction_size(op):
    # LR35902 instruction boundaries matter even in short code signatures:
    # a pointer's low byte can itself equal LD/JP/CALL.
    if op in (0x01,0x08,0x11,0x21,0x31,0xc2,0xc3,0xc4,0xca,0xcc,0xcd,
              0xd2,0xd4,0xda,0xdc,0xea,0xfa):return 3
    if op in (0x06,0x0e,0x10,0x16,0x18,0x1e,0x20,0x26,0x28,0x2e,0x30,
              0x36,0x38,0x3e,0xc6,0xcb,0xce,0xd6,0xde,0xe0,0xe6,0xe8,
              0xee,0xf0,0xf6,0xf8,0xfe):return 2
    return 1


def native_bytes(rom, pattern):
    """Relocate native code signatures at instruction boundaries only."""
    if len(rom)<0x143 or rom[0x134:0x13e]!=b'PM_CRYSTAL':return pattern
    pattern=bytearray(pattern);i=0
    place=0x106e if rom[0x142]==ord('S') else 0x1078
    while i<len(pattern):
        op=pattern[i];size=instruction_size(op)
        if i+size>len(pattern):break
        if op in (0x21,0x11,0xfa,0xea,0xcd):
            address=int.from_bytes(pattern[i+1:i+3],'little')
            if op!=0xcd and 0xc3a0<=address<=0xceff:address+=0x100
            elif op==0xcd and address==0x0f74:address=place
            pattern[i+1:i+3]=address.to_bytes(2,'little')
        elif op in (0xe0,0xf0) and pattern[i+1]==0xd6:pattern[i+1]=0xd4
        i+=size
    return bytes(pattern)


def native_match(actual, pattern, rom):
    """Match native Crystal code, keeping instructions and UI coordinates exact.

    Helper CALL destinations and scratch WRAM operands can relocate. The
    verified PlaceString target, ROM pointers, other operands and opcodes stay
    exact. Each caller additionally validates uniqueness and English wording.
    Gold/Silver retain their original byte-exact signatures.
    """
    if len(rom)<0x143 or rom[0x134:0x13e]!=b'PM_CRYSTAL':return actual==pattern
    expected=native_bytes(rom,pattern)
    if len(actual)!=len(expected):return False
    place=0x106e if rom[0x142]==ord('S') else 0x1078
    i=0
    while i<len(expected):
        if actual[i]!=expected[i]:return False
        op=expected[i];size=instruction_size(op)
        if i+size>len(expected):return actual[i:]==expected[i:]
        if op in (0x21,0x11,0xfa,0xea,0xcd):
            address=int.from_bytes(expected[i+1:i+3],'little')
            target=int.from_bytes(actual[i+1:i+3],'little')
            scratch=op!=0xcd and 0xc608<=address<=0xdfff
            helper=op==0xcd and address!=place
            if scratch:
                if not 0xc608<=target<=0xdfff:return False
            elif helper:
                if not 0<=target<0x8000:return False
            elif target!=address:return False
        elif actual[i:i+size]!=expected[i:i+size]:return False
        i+=size
    return True


def decode(rom, bank, address, charmap, operands=None, slots=None, preserve_scroll=True):
    out=[];inside=False;hops=0
    def marker(name,identity=None):
        out.append('{'+name+'}')
        if slots is not None:slots.append(identity or ('named',name))
    for _ in range(4096):
        code=byte(rom,bank,address);address+=1
        if code==0x50:
            if not inside:return ''.join(out),address
            inside=False
        elif code in (0x57,0x58):
            if out:out.append('{DONE}' if code==0x57 else '{PROMPT}')
            return ''.join(out),address
        elif code==0:
            inside=True
        elif code==0x16 and not inside:
            target=word(rom,bank,address);target_bank=byte(rom,bank,address+2)
            hops+=1
            if hops>8:raise ValueError('far text cycle')
            offset(target_bank,target)
            bank,address=target_bank,target
        elif code==1:
            if operands is not None:operands.append(('ram',word(rom,bank,address)))
            marker('STRBUF',('ram',word(rom,bank,address)));address+=2
        elif code==0x4c:
            if preserve_scroll:out.append('\r')
        elif code in (0x4e,0x4f):out.append('\n')
        elif code==0x51:out.append('\f')
        elif code==0x55:out.append('\v')
        elif code==0x52:marker('PLAYER')
        elif code==0x53:marker('RIVAL')
        elif code==0x54:out.append('POKé')
        elif code==6:pass
        elif code==9 and not inside:
            if operands is not None:operands.append(('number',word(rom,bank,address)))
            marker('NUM',('number',word(rom,bank,address)));address+=3
        elif code==0x14 and not inside:
            if operands is not None:operands.append(('buffer',byte(rom,bank,address)))
            marker('STRBUF',('buffer',byte(rom,bank,address)));address+=1
        elif code==0x15 and not inside:marker('DAY')
        elif code==0x0c and not inside:address+=1
        elif not inside and code in (5,7,10,11,13,14,15,16,17,18,19,21):pass
        elif code==0x56:out.append('……')
        else:
            ch=charmap.get(code)
            if ch in ('<USER>','<TARGET>','<ENEMY>','<PLAYER>','<RIVAL>'):marker(ch[1:-1])
            elif ch and not ch.startswith('<'):out.append(ch)
            elif ch and ch.startswith('<'):pass  # known nonprinting engine controls
            else:raise ValueError(f'unknown glyph {code:02x}')
    raise ValueError('unterminated text')



def positional_text(text,original_slots,translated_slots,preserve_named=False):
    if Counter(original_slots)!=Counter(translated_slots):raise ValueError('runtime slot identities differ')
    positions={}
    for index,identity in enumerate(original_slots):positions.setdefault(identity,deque()).append(index+1)
    pending=iter(translated_slots)
    def replace(match):
        if match[0] in ('{DONE}','{PROMPT}'):return match[0]
        if preserve_named and match[0] in ('{PLAYER}','{RIVAL}','{DAY}'):
            return match[0]
        identity=next(pending)
        return '{ARG:'+str(positions[identity].popleft())+'}'
    return re.sub(r'\{[^}]+\}',replace,text)


def phone_buffer_text(text,slots):
    buffers={0xd099:0,0xd0ac:1,0xd0bf:2}
    identities=iter(slots)
    def replace(_):
        kind,address=next(identities)
        if kind!='ram' or address not in buffers:raise ValueError('unknown native phone buffer')
        return '{ESBUF:'+str(buffers[address])+'}'
    return re.sub(r'\{STRBUF\}',replace,text)


def seer_slots(label,slots):
    if label not in ('_SeerNoLocationText','_SeerTimeLevelText','_SeerTradeText'):return slots
    # Crystal's original Spanish Seer puts its time/level/OT scratch fields
    # one byte later. Pokémon and location scratch fields retain their IDs.
    aliases={0xd020:0xd01f,0xd037:0xd036,0xd02b:0xd02a}
    return [(kind,aliases.get(identity,identity)) if kind=='ram' else (kind,identity)
            for kind,identity in slots]


def lua_string(text):
    return '"'+text.replace('\\','\\\\').replace('"','\\"').replace('\n','\\n').replace('\f','\\012').replace('\v','\\011').replace('\r','\\r').replace('\t','\\t')+'"'


def key(point):return f'{point[0]:02x}:{point[1]:04x}'


def tokens(text):return Counter(re.findall(r'\{[^}]+\}',text))


class Mapper:
    def __init__(self,en,es,opcodes):
        self.en,self.es,self.ops=en,es,opcodes
        self.pairs={};self.sources={};self.conflicts=set();self.seen=set();self.rejected=[];self.landmark_names={};self.english_charmap={};self.localized_landmarks=[];self.literal_pairs=[]
        self.targets={};self.context_targets={};self.map_names=set();self.mail_pairs=[]

    def text(self,a,b,source):
        self.targets.setdefault(a,set()).add(b)
        context=source.split('/',1)[0]
        if context in self.map_names:self.context_targets.setdefault(a,{}).setdefault(context,set()).add(b)
        if a in self.pairs and self.pairs[a]!=b:
            self.conflicts.add(a)
        else:self.pairs[a]=b;self.sources[a]=source
        # Keep the data-label correspondence as well as the wrapper pointer.
        for _ in range(8):
            if byte(self.en,*a)!=0x16 or byte(self.es,*b)!=0x16:break
            a=(byte(self.en,a[0],a[1]+3),word(self.en,a[0],a[1]+1))
            b=(byte(self.es,b[0],b[1]+3),word(self.es,b[0],b[1]+1))
            self.targets.setdefault(a,set()).add(b)
            if context in self.map_names:self.context_targets.setdefault(a,{}).setdefault(context,set()).add(b)
            if a in self.pairs and self.pairs[a]!=b:self.conflicts.add(a)
            else:self.pairs[a]=b;self.sources[a]=source+' / text_far'

    def resolve_identical_copies(self,charmap):
        # Crystal moved Route 36's gate into another bank, duplicating the
        # rules shared with Route 35. Different pointers are only equivalent
        # when the complete decoded text AND every runtime field agree.
        for point in sorted(self.conflicts):
            values=[]
            try:
                for target in sorted(self.targets.get(point,())):
                    slots=[];body,_=decode(self.es,*target,charmap,slots=slots)
                    values.append((body,slots))
            except (ValueError,IndexError):continue
            if len(values)>1 and all(value==values[0] for value in values[1:]):
                self.conflicts.remove(point)
                self.sources[point]+=' / identical localized copies '+','.join(key(p) for p in sorted(self.targets[point]))

    def walk(self,a,b,source):
        queue=deque([(a,b,source)])
        local_jumps={'scall','sjump','iffalse','iftrue','stopandsjump','sdefer'}
        conditional={'ifequal','ifnotequal','ifgreater','ifless'}
        ends={'sjump','farsjump','jumpstd','jumptext','farjumptext','jumptextfaceplayer','stopandsjump','end','endall','endcallback','reloadend','return','credits','halloffame','memjump','fruittree','describedecoration'}
        while queue:
            a,b,why=queue.popleft()
            if (a,b) in self.seen:continue
            self.seen.add((a,b))
            for _ in range(256):
                try:
                    code=byte(self.en,*a)
                    if code!=byte(self.es,*b) and self.ops.get(code,{}).get('name')=='getstring' and byte(self.es,*b)==0xa3:
                        ident=byte(self.es,b[0],b[1]+1);buffer=byte(self.es,b[0],b[1]+2)
                        pointer=word(self.en,a[0],a[1]+1)
                        literal,_=name_record(self.en,a[0],pointer,self.english_charmap)
                        normalize=lambda text:' '.join(text.replace('<BSP>',' ').split())
                        if buffer!=byte(self.en,a[0],a[1]+3) or ident not in self.landmark_names or normalize(literal)!=normalize(self.landmark_names[ident]):
                            self.rejected.append([key(a),key(b),why,'Spanish landmark command identity mismatch']);break
                        self.localized_landmarks.append({'english':key(a),'spanish':key(b),'landmark':ident,'buffer':buffer,'source':literal})
                        a=(a[0],a[1]+4);b=(b[0],b[1]+3);continue
                    if code!=byte(self.es,*b) or code not in self.ops:
                        self.rejected.append([key(a),key(b),why,'opcode mismatch']);break
                    info=self.ops[code];name=info['name'];size=info['size']
                    if name=='givepoke' and byte(self.en,a[0],a[1]+4):size=8
                    x=[byte(self.en,a[0],a[1]+i+1) for i in range(size)]
                    y=[byte(self.es,b[0],b[1]+i+1) for i in range(size)]
                    def ptr(point,args,start=0):return (point[0],args[start]+256*args[start+1])
                    def far(args):return (args[0],args[1]+256*args[2])
                    if name in ('writetext','jumptext','jumptextfaceplayer'):
                        self.text(ptr(a,x),ptr(b,y),why)
                    elif name in ('farwritetext','farjumptext'):self.text(far(x),far(y),why)
                    elif name=='winlosstext':
                        for start in (0,2):
                            target=x[start]+256*x[start+1];other=y[start]+256*y[start+1]
                            if target in (0,0xffff):
                                if target!=other:raise ValueError('win/loss sentinel differs')
                            else:self.text(ptr(a,x,start),ptr(b,y,start),why)
                    elif name in local_jumps:
                        queue.append((ptr(a,x),ptr(b,y),why+' / '+name))
                    elif name in conditional:
                        if x[0]!=y[0]:break
                        queue.append((ptr(a,x,1),ptr(b,y,1),why+' / '+name))
                    elif name in ('farscall','farsjump'):
                        queue.append((far(x),far(y),why+' / '+name))
                    elif name=='writecmdqueue':
                        ah=ptr(a,x);bh=ptr(b,y)
                        kind=byte(self.en,*ah)
                        if kind!=byte(self.es,*bh):raise ValueError('command queue kinds differ')
                        if kind==2:
                            at=word(self.en,ah[0],ah[1]+1);bt=word(self.es,bh[0],bh[1]+1)
                            for row in range(16):
                                ar=at+row*4;br=bt+row*4
                                warp=byte(self.en,a[0],ar)
                                if warp!=byte(self.es,b[0],br):raise ValueError('stone table warp differs')
                                if warp==0xff:break
                                if byte(self.en,a[0],ar+1)!=byte(self.es,b[0],br+1):raise ValueError('stone object differs')
                                queue.append(((a[0],word(self.en,a[0],ar+2)),(b[0],word(self.es,b[0],br+2)),why+'/stone/'+str(row)))
                            else:raise ValueError('unterminated stone table')
                    elif name=='getstring':
                        # dw text pointer, then db string-buffer id.
                        if x[2]!=y[2]:break
                        self.literal_pairs.append({'english':key(ptr(a,x)),'spanish':key(ptr(b,y)),'source':why})
                    elif name=='givepoke' and size==8:
                        if x[:4]!=y[:4]:break
                    elif name in ('applymovement','applymovementlasttalked'):
                        # Pointers relocate; object/buffer identity must agree.
                        if size==3 and x[0]!=y[0]:break
                    elif name in ('givepokemail','checkpokemail'):
                        self.mail_pairs.append({'english':key(ptr(a,x)), 'spanish':key(ptr(b,y)), 'command':name, 'source':why})
                    elif name in ('callasm','loadmenu','memcall','memjump','memcallasm','elevator','writecmdqueue'):
                        pass  # ROM addresses can relocate with localization.
                    elif x!=y:
                        self.rejected.append([key(a),key(b),why,'operand mismatch: '+name]);break
                    if name in ends:break
                    a=(a[0],a[1]+1+size);b=(b[0],b[1]+1+size)
                except (ValueError,IndexError):
                    self.rejected.append([key(a),key(b),why,'invalid pointer']);break




    def hall_of_fame(self,manifest):
        labels=['AnimateHallOfFame.String_NewHallOfFamer','_HallOfFamePC.HOFMaster','_HallOfFamePC.TimeFamer']
        points=[tuple(manifest['symbols'][label]) for label in labels]
        bank=points[0][0]
        if any(point[0]!=bank for point in points):raise ValueError('Hall of Fame label bank differs')
        # Anchor the call site to the named English header, then pair the
        # same hlcoord placement. Crystal moved tile RAM and PlaceString.
        text=points[0][1]
        raw=bytes([0x11,text&255,text>>8])
        start=offset(bank,0x4000);chunk=self.en[start:start+0x4000]
        sites=[i for i in range(len(chunk)-9) if chunk[i:i+3]==raw and chunk[i+3]==0x21 and chunk[i+6]==0xcd]
        if len(sites)!=1:raise ValueError('Hall of Fame header reference must be unique')
        signature=chunk[sites[0]+3:sites[0]+7] # hlcoord 1,2; call
        def references(rom):
            start=offset(bank,0x4000);cursor=start;result=[]
            while True:
                cursor=rom.find(signature,cursor,start+0x4000)
                if cursor<0:break
                if cursor>=start+3 and rom[cursor-3]==0x11:
                    address=cursor-start+0x4000
                    result.append(((bank,address-3),(bank,word(rom,bank,address-2))))
                cursor+=1
            return result
        aa=references(self.en);bb=references(self.es)
        if [target for _,target in aa]!=points or len(bb)!=3:raise ValueError('Hall of Fame print-reference identity differs')
        self.hof_references={}
        for label,(reference,a),(other,b) in zip(labels,aa,bb):
            self.text(a,b,'native Hall of Fame header print / '+label)
            self.hof_references[label]={'english':key(reference),'spanish':key(other),'text':key(b)}

    def far_texts(self,points):
        for point in sorted(points):
            if point in self.pairs:continue
            target=point
            for _ in range(8):
                if byte(self.en,*target)!=0x16:break
                target=(byte(self.en,target[0],target[1]+3),word(self.en,target[0],target[1]+1))
            if target!=point and target in self.pairs and target not in self.conflicts:
                self.text(point,self.pairs[target],'resolved text_far data / '+key(target))

    def phone(self,manifest):
        self.english_charmap={int(k):v for k,v in manifest.get('charmap',{}).items()}
        if 'Landmarks' in manifest['symbols']:
            lb,la=manifest['symbols']['Landmarks']
            for index,_ in enumerate(manifest['constants']['landmarkOrder']):
                self.landmark_names[index]=name_record(self.en,lb,word(self.en,lb,la+index*4+2),self.english_charmap)[0]
        bank,address=manifest['symbols']['PhoneContacts']
        contacts=manifest['constants']['phoneContactOrder'];size=12*len(contacts)
        source=bytes(byte(self.en,bank,address+i) for i in range(size))
        static=[12*row+i for row in range(len(contacts)) for i in (0,1,2,3,4,5,8,9)]
        start=offset(bank,0x4000);candidates=[]
        cursor=start
        while True:
            cursor=self.es.find(source[:6],cursor,start+0x4000)
            if cursor<0:break
            if cursor+size<=start+0x4000 and all(self.es[cursor+i]==source[i] for i in static):
                candidates.append(cursor-start+0x4000)
            cursor+=1
        if len(candidates)!=1:raise ValueError('phone table identity is not unique')
        target=candidates[0]
        self.phone_table={'english':key((bank,address)),'spanish':key((bank,target)),'contacts':len(contacts)}
        for row,contact in enumerate(contacts):
            for role,index in [('callee',5),('caller',9)]:
                a=address+12*row+index;b=target+12*row+index
                first=(byte(self.en,bank,a),word(self.en,bank,a+1))
                second=(byte(self.es,bank,b),word(self.es,bank,b+1))
                offset(*first);offset(*second)
                self.walk(first,second,'phone/'+contact+'/'+role)


        if 'SpecialPhoneCallList' in manifest['symbols']:
            special_bank,special_address=manifest['symbols']['SpecialPhoneCallList']
            if special_bank!=bank or special_address!=address+size:raise ValueError('special phone table boundary differs')
            for row,ident in enumerate(manifest['constants']['specialCallOrder'][1:]):
                a=special_address+row*6;b=target+size+row*6
                if byte(self.en,bank,a+2)!=byte(self.es,bank,b+2):raise ValueError('special phone contact differs')
                first=(byte(self.en,bank,a+3),word(self.en,bank,a+4))
                second=(byte(self.es,bank,b+3),word(self.es,bank,b+4))
                self.walk(first,second,'special-phone/'+ident)

    def maps(self,maps):
        self.map_names=set(maps['en'])
        for name in sorted(maps['en']):
            en=maps['en'][name]
            es=maps['es'][name];eb=en['scripts']['bank'];sb=es['scripts']['bank']
            for field in ('objects','bgEvents','coordEvents','callbacks','sceneScripts'):
                aa=en.get(field,[]);bb=es.get(field,[])
                if isinstance(aa,dict):
                    if set(aa)!=set(bb):raise ValueError(f'{name}: {field} identities differ')
                    identities=sorted(aa)
                    aa=[aa[k] for k in identities];bb=[bb[k] for k in identities]
                if len(aa)!=len(bb):raise ValueError(f'{name}: {field} count differs')
                for index,(x,y) in enumerate(zip(aa,bb)):
                    if not x.get('script') or not y.get('script'):continue
                    why=f'{name}/{field}/{index}'
                    if field=='objects' and x.get('type')==1:continue  # item ball
                    if field=='bgEvents' and x.get('kind')==7:continue  # hidden item
                    a=(eb,x['script']);b=(sb,y['script'])
                    try:offset(*a);offset(*b)
                    except ValueError:continue
                    if field=='objects' and x.get('type')==2:
                        # Trainer records: event, class/id, three texts, after-script.
                        if bytes(byte(self.en,eb,a[1]+i) for i in range(4))!=bytes(byte(self.es,sb,b[1]+i) for i in range(4)):
                            continue
                        for start in (4,6,8):
                            ap=word(self.en,eb,a[1]+start);bp=word(self.es,sb,b[1]+start)
                            if ap and bp:self.text((eb,ap),(sb,bp),why+'/trainer')
                        a=(eb,word(self.en,eb,a[1]+10));b=(sb,word(self.es,sb,b[1]+10))
                    if a[1] and b[1]:
                        if a[1]<0x4000:a=(0,a[1])
                        if b[1]<0x4000:b=(0,b[1])
                        self.walk(a,b,why)
        a=maps['en_std']['scripts'];b=maps['es_std']['scripts']
        if isinstance(a,list):a={str(i+1):v for i,v in enumerate(a)}
        if isinstance(b,list):b={str(i+1):v for i,v in enumerate(b)}
        for ident,entry in sorted(a.items()):
            other=b.get(ident)
            if other:self.walk((entry['bank'],entry['address']),(other['bank'],other['address']),'std/'+ident)



def terminal(text):
    return re.sub(r"\{(?:DONE|PROMPT)\}$", "", text)


def common_tables(mapper, symbols, catalog, english, spanish,banks=(0x64,0x65,0x66)):
    """Pair contiguous common-text records; validate the entire table before use."""
    for bank in banks:
        entries=sorted((symbols[label][1],label) for label in catalog if symbols[label][0]==bank)
        if not entries or entries[0][0]!=0x4000:raise ValueError('common table start differs')
        pending=[];cursor=0x4000
        for index,(address,label) in enumerate(entries):
            a=(bank,address);b=(bank,cursor)
            en,end=decode(mapper.en,*a,english)
            es,cursor=decode(mapper.es,*b,spanish)
            if tokens(terminal(en))!=tokens(terminal(es)):
                raise ValueError('common table placeholder mismatch: '+label)
            if a in mapper.pairs and mapper.pairs[a]!=b:
                raise ValueError('common table script anchor mismatch: '+label)
            if index+1<len(entries):
                next_address=entries[index+1][0]
                if end>next_address or any(byte(mapper.en,bank,n)!=0x50 for n in range(end,next_address)):
                    raise ValueError('noncontiguous English table: '+label)
            pending.append((a,b,label))
            while byte(mapper.es,bank,cursor)==0x50:cursor+=1
        for a,b,label in pending:mapper.text(a,b,'common text table / '+label)
    # English engine labels often wrap the shared records through text_far.
    for label in sorted(catalog):
        a=tuple(symbols[label]);target=a
        for _ in range(8):
            if byte(mapper.en,*target)!=0x16:break
            target=(byte(mapper.en,target[0],target[1]+3),word(mapper.en,target[0],target[1]+1))
        if a not in mapper.pairs and target in mapper.pairs:
            mapper.text(a,mapper.pairs[target],'named text_far target / '+label)




def anchored_text_blocks(mapper,symbols,catalog,english,spanish,banks=(0x40,),strict=True):
    """Recover complete inline tables starting at an independently paired script anchor."""
    for bank in banks:
        entries=sorted((symbols[label][1],label) for label in catalog if symbols[label][0]==bank)
        groups=[];group=[];previous_end=None
        for address,label in entries:
            if byte(mapper.en,bank,address) not in (0,1,9,0x0a,0x14):
                if group:groups.append(group);group=[]
                previous_end=None;continue
            original,end=decode(mapper.en,bank,address,english)
            if original!=catalog[label]:raise ValueError('inline table differs from English cache: '+label)
            if group and (previous_end>address or any(byte(mapper.en,bank,n)!=0x50 for n in range(previous_end,address))):
                groups.append(group);group=[]
            group.append((address,label,original));previous_end=end
        if group:groups.append(group)
        for group in groups:
            first=(bank,group[0][0])
            if len(group)<2 or first in mapper.conflicts:continue
            if first not in mapper.pairs:
                # Crystal's battle strings follow native code rather than a
                # map sign. Match the whole contiguous record structure, not
                # a nearby address or one short repeated sentence.
                if len(group)<8:continue
                candidates=[]
                for candidate in range(0x4000,0x8000):
                    if byte(mapper.es,bank,candidate)!=byte(mapper.en,*first):continue
                    cursor=candidate
                    try:
                        for address,label,original in group:
                            point=(bank,address)
                            if point in mapper.pairs and mapper.pairs[point]!=(bank,cursor):raise ValueError('anchor differs')
                            translated,cursor=decode(mapper.es,bank,cursor,spanish)
                            if tokens(terminal(original))!=tokens(terminal(translated)):raise ValueError('record shape differs')
                            while cursor<0x8000 and byte(mapper.es,bank,cursor)==0x50:cursor+=1
                        candidates.append(candidate)
                    except (ValueError,IndexError):pass
                if len(candidates)!=1:continue
                mapper.text(first,(bank,candidates[0]),'unique full contiguous record structure / '+key(first))
            target_bank,cursor=mapper.pairs[first]
            if target_bank!=bank:continue
            pending=[]
            for address,label,original in group:
                a=(bank,address);b=(bank,cursor)
                translated,cursor=decode(mapper.es,*b,spanish)
                if tokens(terminal(original))!=tokens(terminal(translated)):
                    if not strict:pending=[];break
                    raise ValueError('anchored table placeholder mismatch: '+label)
                if a in mapper.pairs and mapper.pairs[a]!=b:
                    if not strict:pending=[];break
                    raise ValueError('anchored table disagrees with script anchor: '+label)
                pending.append((a,b,label))
                while byte(mapper.es,bank,cursor)==0x50:cursor+=1
            for a,b,label in pending:mapper.text(a,b,'contiguous text block / '+key(first)+' / '+label)


def name_record(rom, bank, address, charmap, limit=32, fixed=False):
    """Plain @-terminated ROM strings, not executable text scripts."""
    out=[]
    for index in range(limit):
        code=byte(rom,bank,address+index)
        if code==0x50:return ''.join(out),address+index+1
        if code not in charmap:raise ValueError(f'unknown name glyph {code:02x}')
        out.append(charmap[code])
    if fixed:return ''.join(out),address+limit
    raise ValueError('unterminated name record')


def extract_pokedex_entries(en,es,manifest,english,spanish):
    bank,address=manifest['symbols']['PokedexDataPointerTable']
    crystal=manifest['symbols'].get('PokemonNames',[0])[0]!=manifest['symbols'].get('ItemNames',[0])[0]
    suffix=bytes.fromhex('4f060009090707e603c668f53e')+bytes([bank,0xcd])
    def locate(rom):
        hits=[];ref_bank=17 if crystal else 46
        for ref in range(0x4000,0x8000-len(suffix)-3):
            start=offset(ref_bank,ref)
            matched=(native_match(rom[start+3:start+18],bytes.fromhex('783d16005f19195e2356d50707e603'),rom)) if crystal else native_match(rom[start+3:start+3+len(suffix)],suffix,rom)
            if rom[start]==0x21 and matched:
                pointer=word(rom,ref_bank,ref+1)
                hits.append((pointer,(ref_bank,ref)))
        if len(hits)!=1:raise ValueError('Pokedex native table loader must be unique')
        return hits[0]
    (a,ar),(b,br)=locate(en),locate(es)
    if a!=address:raise ValueError('English Pokedex table differs from manifest')
    entries={};proof={}
    for index,species in enumerate(manifest['constants']['speciesOrder']):
        if species=='UNUSED':continue
        label=manifest['pokemonAssets'][species]['dexLabel']
        entry_bank=manifest['symbols'][label][0]
        old=word(en,bank,a+index*2);new=word(es,bank,b+index*2)
        if manifest['symbols'][label]!=[entry_bank,old]:
            raise ValueError('English Pokedex species pointer differs: '+species)
        old_kind,cursor=name_record(en,entry_bank,old,english,32)
        old_height=word(en,entry_bank,cursor);old_weight=word(en,entry_bank,cursor+2)
        old_text,cursor=name_record(en,entry_bank,cursor+4,english,256)
        old_text2,_=name_record(en,entry_bank,cursor,english,256)
        kind,cursor=name_record(es,entry_bank,new,spanish,32)
        height=byte(es,entry_bank,cursor);weight=word(es,entry_bank,cursor+1)
        text,cursor=name_record(es,entry_bank,cursor+3,spanish,256)
        text2,_=name_record(es,entry_bank,cursor,spanish,256)
        if not all([old_kind,old_text,old_text2,kind,text,text2,old_height,old_weight,height,weight]):
            raise ValueError('empty Pokedex field: '+species)
        entries[species]={'kind':kind,'heightM':height/10,'weightKg':weight/10,'text':text,'text2':text2}
        proof[species]={'english':key((entry_bank,old)),'spanish':key((entry_bank,new)),
            'height_decimetres':height,'weight_hectograms':weight}
    return entries,{'table':{'english':key((bank,a)),'spanish':key((bank,b)),
        'english_reference':key(ar),'spanish_reference':key(br)},
        'measurement_bytes':{'english':4,'spanish':3},'entries':proof}


def decompress_lz3(data,engine):
    program='package.path='+lua_value(str(engine.resolve())+'/?.lua;')+'..package.path;'
    program+='local b=require("src.import.Rom").decompressLz3(io.read("*a"));for i=1,#b do io.write(string.char(b[i])) end'
    return subprocess.run(['luajit','-e',program],input=data,stdout=subprocess.PIPE,stderr=subprocess.PIPE,check=True).stdout


def locate_title_tilemap(rom):
    """Find the Gold title tilemap through its native VRAM copy loop."""
    tail=bytes.fromhex('11 00 98 3e 26 cd')
    end=bytes.fromhex('fe ff 28 05 23 12 13 18 f2')
    hits=[]
    for at in range(len(rom)-20):
        if rom[at]==0x21 and rom[at+3:at+9]==tail and rom[at+11:at+20]==end:
            bank=rom[at+7]
            address=rom[at+1]+256*rom[at+2]
            hits.append((bank,address))
    if len(hits)!=1:
        raise ValueError('Gold title tilemap copy loop must be unique')
    return hits[0]


def audit_gamefreak_splash(en,es,manifest):
    """Prove the Spanish cart retains the shared Game Freak splash wording."""
    bank,address=manifest['symbols']['GameFreakLogoGFX']
    source=en[offset(bank,address):offset(bank,address)+28*8]
    if len(source)!=28*8:raise ValueError('English Game Freak splash sheet is truncated')
    bank_start=offset(bank,0x4000)
    bank_end=bank_start+0x4000
    graphics_hits=[at for at in range(bank_start,bank_end-len(source)+1)
        if es[at:at+len(source)]==source]
    if len(graphics_hits)!=1:
        raise ValueError('Spanish Game Freak splash sheet must have one exact match')
    if en[0x134:0x13e]==b'PM_CRYSTAL':
        # Crystal's Ditto splash does not use Gold's word-placement routine.
        # The engine renders the thirteen letter tiles directly from this
        # symbol. Audit the complete native sheet, without claiming Gold's
        # unrelated instruction sequence exists in Crystal.
        return {'english_graphics':key((bank,address)),
            'spanish_graphics':key((bank,graphics_hits[0]-bank_start+0x4000)),
            'graphics_bytes':len(source),'same_graphics':True,
            'scope':'Crystal original letter and logo graphics identity'}
    head=bytes.fromhex('cd 74 0f cd')
    tail=bytes.fromhex('3e 80 ea 65 ce c9 87 88 89 8a 8b 8c 50')
    def sequence(rom):
        hits=[]
        for at in range(bank_start,bank_end-len(head)-2-len(tail)+1):
            if rom[at:at+len(head)]==head and rom[at+len(head)+2:at+len(head)+2+len(tail)]==tail:
                hits.append((at,rom[at+len(head):at+len(head)+2]))
        if len(hits)!=1:raise ValueError('Game Freak splash word sequence must be unique')
        return hits[0]
    english_at,english_call=sequence(en)
    spanish_at,spanish_call=sequence(es)
    english_tiles=tuple(en[english_at+12:english_at+18])
    spanish_tiles=tuple(es[spanish_at+12:spanish_at+18])
    if english_tiles!=spanish_tiles:
        raise ValueError('Spanish Game Freak splash changed its original word tiles')
    return {'english_graphics':key((bank,address)),
        'spanish_graphics':key((bank,graphics_hits[0]-bank_start+0x4000)),
        'graphics_bytes':len(source),'same_graphics':True,
        'english_word_reference':key((bank,english_at-bank_start+0x4000)),
        'spanish_word_reference':key((bank,spanish_at-bank_start+0x4000)),
        'english_call':english_call.hex(),'spanish_call':spanish_call.hex(),
        'english_sequence':list(english_tiles),'spanish_sequence':list(spanish_tiles),
        'intentional_unchanged_text':'PRESENTS'}


def rgba_png(raw,width,height):
    if len(raw)!=width*height*4:raise ValueError('RGBA dimensions/payload differ')
    def chunk(name,payload):
        return struct.pack('>I',len(payload))+name+payload+struct.pack('>I',zlib.crc32(name+payload))
    rows=b''.join(b'\0'+raw[y*width*4:(y+1)*width*4] for y in range(height))
    return (b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',width,height,8,6,0,0,0))
            +chunk(b'IDAT',zlib.compress(rows,9))+chunk(b'IEND',b''))


def extract_title_graphics(en,es,manifest,engine,edition='gold'):
    """Rebuild Gold's title background from the original Spanish ROM."""
    title_bank,title_address=manifest['symbols']['TitleScreenTilemap']
    if locate_title_tilemap(en)!=(title_bank,title_address):
        raise ValueError('English title tilemap differs from manifest')
    spanish_bank,spanish_address=locate_title_tilemap(es)
    if spanish_bank!=title_bank:
        raise ValueError('Spanish title tilemap moved to an unexpected bank')
    gfx1_bank,gfx1_address=manifest['symbols']['TitleScreenGFX1']
    gfx2_bank,gfx2_address=manifest['symbols']['TitleScreenGFX2']
    gfx2_delta=title_address-gfx2_address
    if gfx1_bank!=title_bank or gfx2_bank!=title_bank or gfx2_delta<=0:
        raise ValueError('Gold title graphics are not in their expected bank/layout')
    spanish_gfx2=spanish_address-gfx2_delta
    if spanish_gfx2<=gfx1_address:
        raise ValueError('Spanish title graphics overlap')
    english_gfx1=decompress_lz3(en[offset(gfx1_bank,gfx1_address):],engine)
    english_gfx2=decompress_lz3(en[offset(gfx2_bank,gfx2_address):],engine)
    gfx1=decompress_lz3(es[offset(gfx1_bank,gfx1_address):],engine)
    gfx2=decompress_lz3(es[offset(title_bank,spanish_gfx2):],engine)
    if len(gfx1)!=len(english_gfx1) or len(gfx2)!=len(english_gfx2):
        raise ValueError('Spanish title graphics have unexpected decoded dimensions')

    def tiles(raw):
        if len(raw)%16:raise ValueError('title graphics are not complete 2bpp tiles')
        decoded=[]
        for start in range(0,len(raw),16):
            pixels=[]
            for y in range(8):
                low,high=raw[start+y*2:start+y*2+2]
                pixels.extend(((low>>(7-x))&1)+2*((high>>(7-x))&1) for x in range(8))
            decoded.append(pixels)
        return decoded

    first,second=tiles(gfx1),tiles(gfx2)
    map_start=offset(spanish_bank,spanish_address)
    map_end=map_start+(0x8000-spanish_address)
    tilemap=es[map_start:map_end]
    try:terminator=tilemap.index(0xff)
    except ValueError as exc:raise ValueError('Spanish title tilemap has no terminator') from exc
    tilemap=tilemap[:terminator]
    if len(tilemap)>32*18:raise ValueError('Spanish title tilemap exceeds the screen')
    screen=bytearray(160*144)
    for index,tile_id in enumerate(tilemap):
        tile=first[tile_id] if tile_id<0x80 and tile_id<len(first) else (
            second[tile_id-0x80] if tile_id>=0x80 and tile_id-0x80<len(second) else None)
        if tile is None:raise ValueError(f'Spanish title tile id out of range: {tile_id:02x}')
        tx=(index%32)*8;ty=(index//32)*8
        for y in range(8):
            if ty+y>=144:continue
            for x in range(8):
                if tx+x<160:screen[(ty+y)*160+tx+x]=tile[y*8+x]

    palettes=(
        ((31,31,31),(18,23,31),(15,20,31),(0,0,0)),
        ((31,21,0),(12,14,12),(15,20,31),(0,0,17)),
        ((31,31,31),(31,0,0),(15,20,31),(0,0,0)),
        ((31,31,31),(29,25,0),(15,20,31),(17,10,1)),
        ((31,31,31),(23,26,31),(18,23,31),(0,0,0)),
    )
    if edition=='silver':
        palettes=(
            ((31,31,31),(0,12,15),(4,8,21),(0,0,0)),
            ((31,21,0),(15,17,15),(4,8,21),(0,0,17)),
            ((31,31,31),(31,0,0),(4,8,21),(0,0,0)),
            ((31,31,31),(24,23,25),(4,8,21),(8,8,9)),
            ((31,31,31),(5,10,11),(0,12,15),(0,0,0)),
        )
    color=bytearray();gray=bytearray();gray_shades=(255,170,85,0);dmg_map=(0,2,1,3)
    for y in range(144):
        for x in range(160):
            shade=screen[y*160+x]
            col,row=x//8,y//8
            pal=4 if row>=12 else 3 if row==6 and 5<=col<=14 else 1 if row<=6 else 0
            rgb=palettes[pal][shade]
            color.extend((round(rgb[0]*255/31),round(rgb[1]*255/31),round(rgb[2]*255/31),255))
            gray.extend((gray_shades[dmg_map[shade]],)*3+(255,))
    proof={'english_tilemap':key((title_bank,title_address)),
        'spanish_tilemap':key((spanish_bank,spanish_address)),
        'spanish_gfx1':key((gfx1_bank,gfx1_address)),
        'spanish_gfx2':key((title_bank,spanish_gfx2)),
        'tilemap_bytes':len(tilemap),'gfx1_bytes':len(gfx1),'gfx2_bytes':len(gfx2)}
    return rgba_png(color,160,144),rgba_png(gray,160,144),proof


def extract_crystal_title_graphics(en,es,manifest,engine):
    bank,expected=manifest['symbols']['TitleLogoGFX']
    def locate(rom):
        hits=[]
        for address in range(0x4000,0x8000-18):
            p=offset(bank,address)
            if (rom[p]==0x21 and native_match(rom[p+3:p+7],bytes.fromhex('110088cd'),rom)
                    and rom[p+9]==0x21 and native_match(rom[p+12:p+16],bytes.fromhex('110080cd'),rom)
                    and rom[p+7:p+9]==rom[p+16:p+18]):
                hits.append((address,word(rom,bank,address+1),word(rom,bank,address+10)))
        if len(hits)!=1:raise ValueError('Crystal native title graphics pair must be unique')
        return hits[0]
    old,new=locate(en),locate(es)
    if old[1]!=expected or [bank,old[2]]!=manifest['symbols']['TitleCrystalGFX']:
        raise ValueError('English Crystal title graphics differ from manifest')
    original=decompress_lz3(en[offset(bank,old[1]):],engine)
    raw=decompress_lz3(es[offset(bank,new[1]):],engine)
    if len(raw)!=len(original) or len(raw)<153*16:raise ValueError('Crystal title tile count differs')
    pb,pa=manifest['symbols']['TitleScreenPalettes'];start=offset(pb,pa)
    base=offset(pb,0x4000)
    def palette_source(rom):
        hits=[]
        for address in range(0x4000,0x8000-24):
            p=offset(pb,address)
            if (rom[p]==0x21 and native_match(rom[p+3:p+10],bytes.fromhex('1100d0018000cd'),rom)
                    and rom[p+12]==0x21 and native_match(rom[p+15:p+22],bytes.fromhex('1180d0018000cd'),rom)
                    and rom[p+1:p+3]==rom[p+13:p+15] and rom[p+10:p+12]==rom[p+22:p+24]):
                hits.append(word(rom,pb,address+1))
        if len(hits)!=1:raise ValueError('Crystal native title palette pair must be unique')
        return hits[0]
    if palette_source(en)!=pa:raise ValueError('English Crystal palette differs from manifest')
    hit=offset(pb,palette_source(es));pals=es[hit:hit+128]
    rgba=bytearray(160*144*4);gray=bytearray(len(rgba))
    def paint(tile,x0,y0):
        for y in range(8):
            for x in range(8):
                low,high=raw[tile*16+y*2:tile*16+y*2+2]
                shade=((low>>(7-x))&1)+2*((high>>(7-x))&1)
                if not shade:continue
                col,row=(x0+x)//8,(y0+y)//8
                pal=1 if row==9 and 5<=col<=15 else 2 if 3<=row<=4 else 3 if row==5 else 4 if row==6 else 5 if row==7 else 6 if 8<=row<=9 else 7 if row==17 else 0
                value=int.from_bytes(pals[pal*8+shade*2:pal*8+shade*2+2],'little')
                rgb=tuple(round(((value>>shift)&31)*255/31) for shift in (0,5,10))
                p=((y0+y)*160+x0+x)*4
                rgba[p:p+4]=bytes((*rgb,255));gray[p:p+4]=bytes((255-shade*85,)*3+(255,))
    for row in range(7):
        for col in range(20):paint(row*20+col,col*8,(row+3)*8)
    for i in range(13):paint(140+i,(3+i)*8,136)
    def crop(x,y,w,h):return b''.join(rgba[((y+r)*160+x)*4:((y+r)*160+x+w)*4] for r in range(h))
    images={'crystal_screen.png':rgba_png(rgba,160,144),'crystal_screen_gray.png':rgba_png(gray,160,144),
            'crystal_logo.png':rgba_png(crop(0,24,160,56),160,56),
            'crystal_wordmark.png':rgba_png(crop(40,72,88,8),88,8)}
    return images,{'english_logo':key((bank,old[1])),'spanish_logo':key((bank,new[1])),
                   'english_reference':key((bank,old[0])),'spanish_reference':key((bank,new[0])),
                   'spanish_palettes':key((pb,hit-base+0x4000)),'logo_bytes':len(raw)}


def extract_pokedex_graphics(en,es,manifest,decoder):
    bank,expected=manifest['symbols']['PokedexLZ']
    def locate(rom):
        hits=[]
        for address in range(0x4000,0x8000-20):
            p=offset(bank,address)
            if (rom[p]==0x21 and native_match(rom[p+3:p+7],bytes.fromhex('111093cd'),rom)
                    and rom[p+9]==0x21 and native_match(rom[p+12:p+16],bytes.fromhex('110080cd'),rom)
                    and rom[p+7:p+9]==rom[p+16:p+18] and native_match(rom[p+18:p+20],bytes.fromhex('3e06'),rom)):
                hits.append(word(rom,bank,address+1))
        if len(hits)!=1:raise ValueError('Pokedex graphics loader must be unique')
        return hits[0]
    old,new=locate(en),locate(es)
    if old!=expected:raise ValueError('English Pokedex graphics pointer differs')
    decoded=[decoder(rom[offset(bank,pointer):offset(bank,0x7fff)+1]) for rom,pointer in [(en,old),(es,new)]]
    if any(len(data)!=928 for data in decoded):raise ValueError('Pokedex graphics must contain 58 tiles')
    return decoded[1]+bytes(96),{'tiles':58,'english':key((bank,old)),'spanish':key((bank,new)),
        'english_sha256':hashlib.sha256(decoded[0]).hexdigest(),'spanish_sha256':hashlib.sha256(decoded[1]).hexdigest()}


def extract_pokedex_counters(en,es,english,spanish):
    records=[];proof={}
    for expected,coord,ram in [('SEEN','7dc4','04dc'),('OWN','b9c4','e4db')]:
        def locate(rom,charmap):
            hits=[];bank=16
            for address in range(0x4000,0x8000-12):
                p=offset(bank,address)
                if (not native_match(rom[p:p+4],bytes.fromhex('21'+coord+'11'),rom) or rom[p+6]!=0xcd
                        or not native_match(rom[p+9:p+12],bytes.fromhex('21'+ram),rom)):continue
                pointer=word(rom,bank,address+4);start=offset(bank,pointer)
                stop=rom.find(bytes([255]),start,start+16)
                if stop<0:raise ValueError('unterminated Pokedex counter label')
                hits.append((''.join(charmap[c] for c in rom[start:stop]),(bank,pointer)))
            if len(hits)!=1:raise ValueError('Pokedex counter print must be unique')
            return hits[0]
        (old,a),(new,b)=locate(en,english),locate(es,spanish)
        if old!=expected:raise ValueError('English Pokedex counter differs')
        label='PokedexCounter/'+expected
        records.append({'label':label,'english':old,'spanish':new,'context':'pokedex.list','original_slots':[],'spanish_slots':[]})
        proof[label]={'english':key(a),'spanish':key(b)}
    return records,proof


def extract_pokedex_nest(en,es,english,spanish):
    def locate(rom,charmap,prefix,suffix,span=False):
        hits=[];bank=36;prefix=bytes.fromhex(prefix);suffix=bytes.fromhex(suffix)
        for address in range(0x4000,0x8000-24):
            p=offset(bank,address);mid=p+len(prefix)
            if not native_match(rom[p:mid],prefix,rom) or not native_match(rom[mid+2:mid+2+len(suffix)],suffix,rom):continue
            if span and not native_match(rom[mid+9:mid+14],bytes.fromhex('e1cd740fc9'),rom):continue
            pointer=word(rom,bank,address+len(prefix))
            text,_=name_record(rom,bank,pointer,charmap)
            hits.append((text,(bank,pointer)))
        if len(hits)!=1:raise ValueError('Pokedex nest print must be unique')
        return hits[0]
    old,a=locate(en,english,'21a2c3cd740f606911','cd740fc9')
    new,b=locate(es,spanish,'21a1c311','cd740fc5cd',True)
    if old!="'S NEST":raise ValueError('English Pokedex nest caption differs')
    label='PokedexArea/Nest'
    return [{'label':label,'english':'%s'+old,'spanish':new+'%s','original_slots':[],'spanish_slots':[]}],{
        label:{'english':key(a),'spanish':key(b),'english_name_order':'prefix','spanish_name_order':'suffix',
            'english_column':2,'spanish_column':1}}


def extract_pokegear_graphics(en,es,manifest,decoder):
    gear_bank=manifest['symbols']['PokegearGFX'][0]
    def locate(rom):
        hits=[];bank=36
        for address in range(0x4000,0x8000-22):
            p=offset(bank,address)
            if (rom[p]==0x21 and native_match(rom[p+3:p+9],bytes.fromhex('1100903e3ecd'),rom)
                    and rom[p+11]==0x21 and rom[p+14:p+20]==bytes.fromhex('1100933e')+bytes([gear_bank,0xcd])
                    and rom[p+9:p+11]==rom[p+20:p+22]):
                hits.append([word(rom,bank,address+1),word(rom,bank,address+12)])
        if len(hits)!=1:raise ValueError('Pokegear graphics load pair must be unique')
        return hits[0]
    old,new=locate(en),locate(es);sheet=b'';proof={}
    for index,(symbol,bank) in enumerate([('TownMapGFX',62),('PokegearGFX',gear_bank)]):
        if manifest['symbols'][symbol]!=[bank,old[index]]:raise ValueError('English Pokegear graphics pointer differs')
        streams=[decoder(rom[offset(bank,pointer):offset(bank,0x7fff)+1]) for rom,pointer in [(en,old[index]),(es,new[index])]]
        expected_bytes=768 if symbol=='TownMapGFX' else 736
        if any(len(data)!=expected_bytes for data in streams):raise ValueError('Pokegear graphics tile count differs: '+symbol)
        sheet+=streams[1].ljust(768,b'\0')
        proof[symbol]={'english':key((bank,old[index])),'spanish':key((bank,new[index])),
            'english_sha256':hashlib.sha256(streams[0]).hexdigest(),'spanish_sha256':hashlib.sha256(streams[1]).hexdigest()}
    return sheet,proof


def extract_pokegear_switch(en,es,english,spanish):
    def locate(rom,charmap,coord):
        hits=[];bank=36;prefix=bytes.fromhex('21'+coord+'11');suffix=bytes.fromhex('cd740f2190c4011204')
        for address in range(0x4000,0x8000-16):
            p=offset(bank,address)
            if not native_match(rom[p:p+4],prefix,rom) or not native_match(rom[p+6:p+15],suffix,rom):continue
            pointer=word(rom,bank,address+4);text,_=name_record(rom,bank,pointer,charmap)
            if not text.endswith('▶'):raise ValueError('Pokegear switch arrow differs')
            hits.append((text[:-1].strip(),(bank,pointer)))
        if len(hits)!=1:raise ValueError('Pokegear switch print must be unique')
        return hits[0]
    coord='c0c3' if en[0x134:0x13e]==b'PM_CRYSTAL' else 'c1c3'
    old,a=locate(en,english,coord);new,b=locate(es,spanish,'c0c3')
    if old!='SWITCH':raise ValueError('English Pokegear switch differs')
    label='PokegearClock/Switch'
    return [{'label':label,'english':old,'spanish':new,'context':'pokegear.clock','original_slots':[],'spanish_slots':[]}],{
        label:{'english':key(a),'spanish':key(b),'english_column':13,'spanish_column':12}}


def extract_phone_actions(en,es,english,spanish):
    def locate(rom,charmap):
        bank=36;hits=[]
        for address in range(0x400e,0x8000-7):
            p=offset(bank,address)
            if (not native_match(rom[p:p+7],bytes.fromhex('afe0d6e5d51a6f'),rom) or rom[p-14]!=0x21
                    or rom[p-11]!=0x11 or not native_match(rom[p-8:p-6],bytes.fromhex('1806'),rom)
                    or rom[p-6]!=0x21 or rom[p-3]!=0x11):continue
            points=[word(rom,bank,address-10),word(rom,bank,address-2)]
            menus=[]
            for pointer,header in zip(points,[bytes.fromhex('22c403'),bytes.fromhex('4ac402')]):
                q=offset(bank,pointer)
                # These are data words pointing into wTilemap, followed by
                # an exact row count, rather than instruction operands.
                if rom[0x134:0x13e]==b'PM_CRYSTAL':
                    header=(int.from_bytes(header[:2],'little')+0x100).to_bytes(2,'little')+header[2:]
                if rom[q:q+3]!=header:raise ValueError('phone menu header differs')
                text,_=name_record(rom,bank,pointer+3,charmap,64)
                menus.append(text.split('<NEXT>'))
            if len(menus[0])!=3 or menus[1]!=[menus[0][0],menus[0][2]]:raise ValueError('phone submenu actions disagree')
            hits.append((menus[0],points))
        if len(hits)!=1:raise ValueError('phone menu branch must be unique')
        return hits[0]
    (old,a),(new,b)=locate(en,english),locate(es,spanish)
    if old!=['CALL','DELETE','CANCEL']:raise ValueError('English phone actions differ')
    records=[];proof={}
    for index,source in enumerate(old):
        label='PokegearPhone/'+source
        records.append({'label':label,'english':source,'spanish':new[index],'context':'pokegear.phone','original_slots':[],'spanish_slots':[]})
        proof[label]={'english':key((36,a[0]+3)),'spanish':key((36,b[0]+3)),'row':index,
            'english_fixed_contact_menu':key((36,a[1])),'spanish_fixed_contact_menu':key((36,b[1]))}
    return records,proof


def extract_phone_names(en,es,manifest,english,spanish):
    def locate(rom,charmap):
        prefix=bytes.fromhex('e548060021')
        suffix=bytes.fromhex('09092a5f56e1cd740fc9' if rom[0x134:0x13e]==b'PM_CRYSTAL' else '09092a5f56e1cd740f3e9c02c9')
        hits=[];pos=0
        while True:
            p=rom.find(prefix,pos)
            if p<0:break
            pos=p+1;mid=p+len(prefix)
            if not native_match(rom[mid+2:mid+2+len(suffix)],suffix,rom):continue
            bank=p//0x4000;address=p%0x4000+(0x4000 if bank else 0)
            table=word(rom,bank,address+len(prefix));points=[word(rom,bank,table+2*i) for i in range(5)]
            names=[name_record(rom,bank,q,charmap)[0] for q in points]
            hits.append((names,[(bank,q) for q in points],(bank,table)))
        if len(hits)!=1:raise ValueError('non-trainer phone name table must be unique')
        return hits[0]
    old,a,at=locate(en,english);new,b,bt=locate(es,spanish)
    expected=['----------','MOM','BIKE SHOP','BILL','PROF.ELM']
    if en[0x134:0x13e]==b'PM_CRYSTAL':
        if old!=[expected[0]]+[name+':' for name in expected[1:]]:
            raise ValueError('English Crystal phone contact labels differ')
        # Crystal's call-screen labels include punctuation. The content
        # registry stores contact names, which are also interpolated in prose.
        new=[name.removesuffix(':') for name in new]
    elif old!=expected:raise ValueError('English phone contact names differ')
    ids=manifest['constants']['phoneContactOrder'][:5]
    if len(ids)!=5 or len(set(ids))!=5:raise ValueError('phone contact identities differ')
    return dict(zip(ids,new)),{ident:{'english':key(a[i]),'spanish':key(b[i]),'index':i,
        'english_table':key(at),'spanish_table':key(bt)} for i,ident in enumerate(ids)}


def extract_radio_station_names(en,es,english,spanish):
    specs=[('OAKS_POKEMON_TALK',"OAK's <PK><MN> Talk"),('POKEDEX_SHOW','POKéDEX Show'),
        ('POKEMON_MUSIC','POKéMON Music'),('LUCKY_CHANNEL','Lucky Channel'),('PLACES_AND_PEOPLE','Places & People'),
        ('LETS_ALL_SING',"Let's All Sing!"),('ROCKET_RADIO',"Let's All Sing!"),('POKE_FLUTE_RADIO','POKé FLUTE'),
        ('UNOWN_RADIO','?????'),('EVOLUTION_RADIO','?????')]
    crystal=en[0x134:0x13e]==b'PM_CRYSTAL'
    if crystal:specs.insert(4,('BUENAS_PASSWORD',"BUENA'S PASSWORD"))
    def locate(rom,charmap,index):
        prefix=bytes.fromhex('afeaedceeaf0ce3e2e21') if index==0 else bytes([62,index])+bytes.fromhex('eaedceafeaf0ce3e2e21')
        bank=36;hits=[]
        for address in range(0x4000,0x8000-len(prefix)-9):
            p=offset(bank,address);mid=p+len(prefix)
            if not native_match(rom[p:mid],prefix,rom) or rom[mid+2]!=0xcd or rom[mid+5]!=0x11:continue
            if crystal and index==4:
                if not native_match(rom[mid+8:mid+15],bytes.fromhex('fa4dd8cb47c811'),rom) or rom[mid+17]!=0xc9:continue
                pointer=word(rom,bank,address+len(prefix)+15)
                if name_record(rom,bank,word(rom,bank,address+len(prefix)+6),charmap)[0]!='':
                    raise ValueError('Buena hidden channel must be blank')
            else:
                if rom[mid+8]!=0xc9:continue
                pointer=word(rom,bank,address+len(prefix)+6)
            text,_=name_record(rom,bank,pointer,charmap,64)
            hits.append((text,(bank,pointer),(bank,address)))
        if len(hits)!=1:raise ValueError('radio station loader must be unique: '+str(index))
        return hits[0]
    names={};proof={}
    for index,(station,expected) in enumerate(specs):
        old,a,ar=locate(en,english,index);new,b,br=locate(es,spanish,index)
        if old!=expected:raise ValueError('English radio station name differs: '+station)
        names[station]=new
        proof[station]={'english':key(a),'spanish':key(b),'english_loader':key(ar),'spanish_loader':key(br),'station_id':index}
    return names,proof


def extract_pokedex_not_found(en,es,english,spanish):
    records,proof=extract_native_print_labels(en,es,english,spanish,
        [('The specified type<NEXT>was not found.',16,'11','21b9c4cd740f3e01e0d60e80cd3c03c9')],prefix='PokedexSearchResult',limit=128)
    for record in records:
        for language in ['english','spanish']:
            record[language]=record[language].replace('<NEXT>','\n')
            if len(record[language].split('\n'))!=2:raise ValueError('Pokedex no-result message must have two lines')
    return records,proof


def extract_pokedex_modes(en,es,english,spanish):
    def locate(rom,charmap):
        bank=16;label_hits=[];description_hits=[]
        for address in range(0x4000,0x8000-27):
            p=offset(bank,address)
            if (native_match(rom[p:p+4],bytes.fromhex('21f3c311'),rom)
                    and native_match(rom[p+6:p+18],bytes.fromhex('cd740ffadcc6a7c8216bc411'),rom)
                    and native_match(rom[p+20:p+24],bytes.fromhex('cd740fc9'),rom)):
                first=word(rom,bank,address+4);last=word(rom,bank,address+18)
                labels,_=name_record(rom,bank,first,charmap,128)
                unown,_=name_record(rom,bank,last,charmap,128)
                labels=labels.split('<NEXT>')+[unown]
                if len(labels)!=4:raise ValueError('Pokedex mode labels must have four rows')
                label_hits.append((labels,[first]*3+[last]))
            if (native_match(rom[p:p+4],bytes.fromhex('fad8c621'),rom) and rom[p+6]==0xcd
                    and native_match(rom[p+9:p+22],bytes.fromhex('5d5421b9c4cd740f3e01e0d6c9'),rom)):
                table=word(rom,bank,address+4);points=[word(rom,bank,table+2*i) for i in range(4)]
                lines=[name_record(rom,bank,q,charmap,128)[0].split('<NEXT>') for q in points]
                if any(len(v)!=2 for v in lines):raise ValueError('Pokedex mode descriptions must have two lines')
                description_hits.append((lines,points))
        if len(label_hits)!=1 or len(description_hits)!=1:raise ValueError('Pokedex mode references must be unique')
        return label_hits[0],description_hits[0]
    ((old,a),(old_lines,c)),((new,b),(new_lines,d))=locate(en,english),locate(es,spanish)
    expected_labels=['NEW POKéDEX MODE','OLD POKéDEX MODE','A to Z MODE','UNOWN MODE']
    expected_lines=[['<PK><MN> are listed by','evolution type.'],['<PK><MN> are listed by','official type.'],
        ['<PK><MN> are listed','alphabetically.'],['UNOWN are listed','in catching order.']]
    if old!=expected_labels or old_lines!=expected_lines:raise ValueError('English Pokedex modes differ')
    records=[];proof={}
    for i,mode in enumerate(['NEW','OLD','A-Z','UNOWN']):
        label='PokedexMode/'+mode
        records.append({'label':label,'english':old[i],'spanish':new[i],'original_slots':[],'spanish_slots':[]})
        proof[label]={'english':key((16,a[i])),'spanish':key((16,b[i])),'row':i if i<3 else 0}
    for i,mode in enumerate(['NEW','OLD','A-Z','UNOWN']):
        for line in range(2):
            label='PokedexMode/'+mode+'/'+str(line)
            records.append({'label':label,'english':old_lines[i][line],'spanish':new_lines[i][line],
                'context':'pokedex.mode.'+mode,'original_slots':[],'spanish_slots':[]})
            proof[label]={'english':key((16,c[i])),'spanish':key((16,d[i])),'line':line}
    return records,proof


def extract_pokedex_titles(en,es,english,spanish):
    records=[];proof={}
    for expected,nextcoord in [(' OPTION ','f3c3'),(' SEARCH ','f8c3')]:
        def locate(rom,charmap):
            hits=[];bank=16
            for address in range(0x4000,0x8000-13):
                p=offset(bank,address)
                if (not native_match(rom[p:p+4],bytes.fromhex('21b4c311'),rom) or rom[p+6]!=0xcd
                        or not native_match(rom[p+9:p+13],bytes.fromhex('21'+nextcoord+'11'),rom)):continue
                pointer=word(rom,bank,address+4);start=offset(bank,pointer)
                stop=rom.find(bytes([255]),start,start+32)
                if stop<0:raise ValueError('unterminated Pokedex title')
                raw=rom[start:stop]
                if len(raw)<3 or raw[0]!=0x3b or raw[-1]!=0x3c:raise ValueError('Pokedex title border differs')
                hits.append((''.join(charmap[c] for c in raw[1:-1]),(bank,pointer)))
            if len(hits)!=1:raise ValueError('Pokedex title print must be unique')
            return hits[0]
        (old,a),(new,b)=locate(en,english),locate(es,spanish)
        if old!=expected:raise ValueError('English Pokedex title differs')
        label='PokedexTitle/'+expected.strip()
        records.append({'label':label,'english':expected,'spanish':new,'original_slots':[],'spanish_slots':[]})
        proof[label]={'english':key(a),'spanish':key(b)}
    return records,proof


def extract_pokedex_search_labels(en,es,english,spanish):
    def locate(rom,charmap):
        bank=16;hits=[]
        for address in range(0x4000,0x8000-19):
            p=offset(bank,address)
            if (not native_match(rom[p:p+4],bytes.fromhex('21f3c311'),rom)
                    or not native_match(rom[p+6:p+13],bytes.fromhex('cd740f21a7c411'),rom)
                    or not native_match(rom[p+15:p+19],bytes.fromhex('cd740fc9'),rom)):continue
            points=[word(rom,bank,address+4),word(rom,bank,address+13)]
            pairs=[decode(rom,bank,q,charmap)[0].split('\n') for q in points]
            if any(len(v)!=2 for v in pairs):raise ValueError('Pokedex search record must have two lines')
            hits.append((pairs,points))
        if len(hits)!=1:raise ValueError('Pokedex search print pair must be unique')
        return hits[0]
    (old,a),(new,b)=locate(en,english),locate(es,spanish)
    records=[];proof={}
    for index,expected in enumerate(['TYPE1','TYPE2','BEGIN SEARCH!!','CANCEL']):
        group,line=divmod(index,2)
        if old[group][line]!=expected:raise ValueError('English Pokedex search label differs: '+expected)
        label='PokedexSearch/'+expected
        records.append({'label':label,'english':expected,'spanish':new[group][line],
            'context':'pokedex.search','original_slots':[],'spanish_slots':[]})
        proof[label]={'english':key((16,a[group])),'spanish':key((16,b[group])),'line':line}
    return records,proof


def extract_pokedex_size_labels(en,es,english,spanish):
    def locate(rom,charmap):
        bank=16;hits=[]
        for address in range(0x4000,0x8000-27):
            p=offset(bank,address)
            if (not native_match(rom[p:p+4],bytes.fromhex('2135c411'),rom) or rom[p+6]!=0xcd
                    or not native_match(rom[p+9:p+13],bytes.fromhex('215dc411'),rom) or rom[p+15]!=0xcd
                    or rom[p+7:p+9]!=rom[p+16:p+18]
                    or not native_match(rom[p+18:p+22],bytes.fromhex('21f4c411'),rom) or rom[p+24]!=0xcd
                    or rom[p+7:p+9]!=rom[p+25:p+27]):continue
            pointers=[word(rom,bank,address+4),word(rom,bank,address+13)]
            values=[];end=None
            for pointer in pointers:
                if end is not None and pointer!=end:break
                start=offset(bank,pointer);stop=rom.find(bytes([255]),start,start+32)
                if stop<0:break
                raw=rom[start:stop];head=raw.split(bytes([0x7f]),1)[0]
                if not head or any(c not in charmap for c in head):break
                values.append((''.join(charmap[c] for c in head),(bank,pointer)))
                end=pointer+stop-start+1
            if len(values)!=2:continue
            action=word(rom,bank,address+22)
            if action!=end:continue
            start=offset(bank,action);stop=rom.find(bytes([255]),start,start+32)
            if stop<0 or rom[start]!=0x3b:continue
            raw=rom[start+1:stop]
            if any(c not in charmap for c in raw):continue
            values.append((''.join(charmap[c] for c in raw),(bank,action)))
            hits.append(values)
        if len(hits)!=1:raise ValueError('Pokedex measurement print pair must be unique')
        return hits[0]
    old,new=locate(en,english),locate(es,spanish)
    records=[];proof={}
    for expected,(original,a),(translated,b) in zip(['HT','WT',' PAGE AREA CRY PRNT'],old,new):
        if original!=expected:raise ValueError('English Pokedex measurement label differs')
        label='PokedexSize/'+original
        records.append({'label':label,'english':original,'spanish':translated,'original_slots':[],'spanish_slots':[]})
        proof[label]={'english':key(a),'spanish':key(b)}
    return records,proof


def extract_names(en, es, manifest, english, spanish):
    symbols=manifest['symbols'];const=manifest['constants'];locations={};tables={}
    if symbols['PokemonNames'][0]!=symbols['ItemNames'][0]:
        # Crystal separates these tables. Seed by complete original records,
        # require a unique native bank match, then decode its own full table.
        seeds={'items':None,'trainers':['LÍDER']*8+['RIVAL'],
               'pokemon':['BULBASAUR','IVYSAUR','VENUSAUR'],
               'moves':['DESTRUCTOR','GOLPE KARATE','DOBLEBOFETÓN']}
        labels={'items':'ItemNames','trainers':'TrainerClassNames','pokemon':'PokemonNames','moves':'MoveNames'}
        orders={'items':const['itemOrder'],'trainers':const['trainerClassOrder'][1:],
                'pokemon':const['speciesOrder'],'moves':const['moveOrder']}
        reverse={v:k for k,v in spanish.items() if len(v)==1}
        catalogs={};locations={'english':{},'spanish':{}}
        for kind,label in labels.items():
            bank,address=symbols[label];target=address
            if seeds[kind]:
                raw=b''
                for name in seeds[kind]:
                    encoded=bytes(reverse[ch] for ch in name)+b'\x50'
                    raw+=encoded.ljust(10,b'\x50') if kind=='pokemon' else encoded
                base=offset(bank,0x4000);chunk=es[base:base+0x4000]
                first=chunk.find(raw)
                if first<0 or chunk.find(raw,first+1)>=0:raise ValueError('Crystal name-table identity must be unique: '+label)
                target=first+0x4000
            locations['english'][label]=[bank,address];locations['spanish'][label]=[bank,target]
            cursor=target;values={}
            for index,ident in enumerate(orders[kind]):
                value,end=name_record(es,bank,cursor,spanish,10 if kind=='pokemon' else 32,fixed=kind=='pokemon')
                cursor=cursor+10 if kind=='pokemon' else end
                if ident!='UNUSED':values[ident]=value
            catalogs[kind+'_names']=values
        return catalogs,locations
    # The physical item table contains all 256 slots, including TM/HM names
    # and unused entries. itemNameCount only describes the engine's first tier.
    for language,rom,charmap in [('english',en,english),('spanish',es,spanish)]:
        bank,address=symbols['ItemNames'];cursor=address;records={};points={}
        points['ItemNames']=[bank,cursor];records['items']=[]
        for _ in range(256):
            value,cursor=name_record(rom,bank,cursor,charmap)
            records['items'].append(value)
        points['TrainerClassNames']=[bank,cursor];records['trainers']=[]
        for _ in const['trainerClassOrder'][1:]:
            value,cursor=name_record(rom,bank,cursor,charmap)
            records['trainers'].append(value)
        points['PokemonNames']=[bank,cursor];records['pokemon']=[]
        for index in range(256):
            value,_=name_record(rom,bank,cursor+10*index,charmap,10,fixed=True)
            records['pokemon'].append(value)
        cursor+=2560
        points['MoveNames']=[bank,cursor];records['moves']=[]
        for _ in const['moveOrder']:
            value,cursor=name_record(rom,bank,cursor,charmap)
            records['moves'].append(value)
        if language=='english':
            for label,point in points.items():
                if point!=symbols[label]:raise ValueError('name table boundary mismatch: '+label)
        locations[language]=points;tables[language]=records
    catalogs={}
    for kind,order in [('items',const['itemOrder']),('trainers',const['trainerClassOrder'][1:]),('pokemon',const['speciesOrder']),('moves',const['moveOrder'])]:
        catalogs[kind+'_names']={ident:tables['spanish'][kind][index] for index,ident in enumerate(order) if ident!='UNUSED'}
    return catalogs,locations



def trainer_party(rom,bank,address,charmap):
    name,cursor=name_record(rom,bank,address,charmap,16)
    payload_start=cursor;kind=byte(rom,bank,cursor);cursor+=1
    if kind not in (0,1,2,3):raise ValueError('invalid trainer party type')
    count=0
    while byte(rom,bank,cursor)!=0xff:
        if count>=6:raise ValueError('trainer party exceeds six')
        level=byte(rom,bank,cursor);species=byte(rom,bank,cursor+1)
        if not 1<=level<=100 or not 1<=species<=251:raise ValueError('invalid trainer party member')
        cursor+=2+(1 if kind in (2,3) else 0)+(4 if kind in (1,3) else 0);count+=1
    cursor+=1
    payload=bytes(byte(rom,bank,n) for n in range(payload_start,cursor))
    return name,cursor,payload


def extract_trainer_names(en,es,manifest,english,spanish):
    bank,address=manifest['symbols']['TrainerGroups'];const=manifest['constants']
    order=const['trainerClassOrder'][1:];catalog={};points={}
    # The group table is anchored by its first pointer to the adjacent roster.
    for rom in (en,es):
        if word(rom,bank,address)!=address+2*len(order):raise ValueError('trainer group anchor differs')
    for index,ident in enumerate(order):
        a=word(en,bank,address+index*2);b=word(es,bank,address+index*2)
        names={};locations={}
        members=const['trainerClassMembers'].get(ident,[])
        for trainer_index in range(len(members)):
            source_a=a;source_b=b
            _,a,payload_a=trainer_party(en,bank,a,english)
            name,b,payload_b=trainer_party(es,bank,b,spanish)
            if payload_a!=payload_b:raise ValueError('trainer gameplay data differs: '+ident)
            names[str(trainer_index+1)]=name
            locations[str(trainer_index+1)]={'english':key((bank,source_a)),'spanish':key((bank,source_b))}
        if index+1<len(order):
            if a!=word(en,bank,address+(index+1)*2) or b!=word(es,bank,address+(index+1)*2):
                raise ValueError('trainer group boundary mismatch: '+ident)
        catalog[ident]=names;points[ident]=locations
    return catalog,points



def description_table(rom,bank,address,count,charmap,slots):
    header_end=address+2*slots
    if word(rom,bank,address)!=header_end:raise ValueError('description table boundary mismatch')
    values=[];points=[]
    for index in range(count):
        pointer=word(rom,bank,address+2*index)
        if pointer<header_end:raise ValueError('description points inside pointer table')
        value,_=name_record(rom,bank,pointer,charmap,128)
        values.append(value);points.append((bank,pointer))
    return values,points


def extract_descriptions(en,es,manifest,english,spanish,cache):
    catalogs={};sources={}
    for kind,label,order_key,slots in [('items','ItemDescriptions','itemOrder',256),('moves','MoveDescriptions','moveOrder',257)]:
        bank,address=manifest['symbols'][label];order=manifest['constants'][order_key]
        if kind=='items' and manifest['symbols'].get('PokemonNames',[0])[0]!=manifest['symbols'].get('ItemNames',[0])[0]:slots=255
        original,aa=description_table(en,bank,address,len(order),english,slots)
        target=address
        if manifest['symbols'].get('PokemonNames',[0])[0]!=manifest['symbols'].get('ItemNames',[0])[0]:
            candidates=[]
            for candidate in range(0x4000,0x8000-2*slots):
                if word(es,bank,candidate)!=candidate+2*slots:continue
                try:
                    description_table(es,bank,candidate,len(order),spanish,slots)
                    candidates.append(candidate)
                except (ValueError,IndexError):pass
            if len(candidates)!=1:raise ValueError('Crystal description-table identity must be unique: '+label)
            target=candidates[0]
        translated,bb=description_table(es,bank,target,len(order),spanish,slots)
        values={};points={}
        for index,ident in enumerate(order):
            if ident=='UNUSED':continue
            if cache[kind][ident]['description']!=original[index]:
                raise ValueError('English description differs from engine cache: '+ident)
            values[ident]=translated[index]
            points[ident]={'english':key(aa[index]),'spanish':key(bb[index])}
        catalogs[kind+'_descriptions']=values;sources[kind]=points
    return catalogs,sources


def lua_value(value):
    if isinstance(value,str):return lua_string(value)
    if isinstance(value,int):return str(value)
    if isinstance(value,float) and math.isfinite(value):return repr(value)
    if isinstance(value,list):return '{'+', '.join(lua_value(v) for v in value)+'}'
    if isinstance(value,dict):return '{'+', '.join('['+lua_string(k)+'] = '+lua_value(v) for k,v in sorted(value.items()))+'}'
    raise TypeError('unsupported catalog value')


def write_catalog(path,values):
    path.parent.mkdir(parents=True,exist_ok=True)
    path.write_text('-- Copied from the original Spanish cartridge; see provenance.json.\nreturn {\n'+''.join(f'  [{lua_string(k)}] = {lua_value(v)},\n' for k,v in sorted(values.items()))+'}\n',encoding='utf-8')



FORMAT=re.compile(r'%(?:[0-9]+\$)?[-+ #0]*[0-9]*(?:\.[0-9]+)?[sdifuFgG]')
ENGINE_TEXT_ABBREVIATIONS=(
    ('#MON','POKéMON'), ('#DEX','POKéDEX'), ('# BALLS','POKé BALLS'),
    ('#\vBALLS','POKé\vBALLS'), ('#\fBALLS','POKé\fBALLS'),
    ('...','…'),
)


def string_shape(text):
    text=terminal(text)
    text=re.sub(r'\{[^}]+\}','{SLOT}',text)
    text=FORMAT.sub('{SLOT}',text)
    return ' '.join(text.split())


def slot_marker(identity):
    if isinstance(identity,str):return identity
    if not isinstance(identity,(tuple,list)) or not identity:return None
    kind=identity[0]
    if kind in ('ram','buffer'):return 'STRBUF'
    if kind=='number':return 'NUM'
    if kind=='named' and len(identity)>1:return identity[1]
    return None


def extract_battler_prefix(en,es,english,spanish):
    crystal=en[0x134:0x13e]==b'PM_CRYSTAL'
    prefix=bytes.fromhex('d5a720051121c6185c11' if crystal else 'd5a720051101cb184411')
    suffix=bytes.fromhex('cd740f6069116cc6184f' if crystal else 'cd740f606911f6ca1837')
    def locate(rom,charmap):
        native_prefix=prefix;native_suffix=suffix
        if crystal and rom[0x142]==ord('S'):
            native_prefix=bytes.fromhex('d5a720051121c6185911')
            native_suffix=bytes.fromhex('cd740f60691116c6184c')
        hits=[]
        for address in range(0,0x4000-len(prefix)-2-len(suffix)):
            mid=address+len(prefix)
            if not native_match(rom[address:mid],native_prefix,rom) or not native_match(rom[mid+2:mid+2+len(suffix)],native_suffix,rom):continue
            pointer=int.from_bytes(rom[mid:mid+2],'little')
            value,_=name_record(rom,0,pointer,charmap)
            hits.append((value,(0,pointer)))
        if len(hits)!=1:raise ValueError('battler-name loader must be unique')
        return hits[0]
    (old,a),(new,b)=locate(en,english),locate(es,spanish)
    if old!='Enemy ':raise ValueError('English battler prefix identity differs')
    return [{'label':'BattleNames/prefix','english':old+'%s','spanish':new+'%s','original_slots':[],'spanish_slots':[]}],{
        'BattleNames/prefix':{'english':key(a),'spanish':key(b)}}


def bind_stat_charge_messages(records):
    by_label={row['label']:row for row in records};result=[];proof={}
    specs=[('rise',"%s's %s rose!",['Text_BattleEffectActivate','_BattleStatWentUpText'],"{USER}'s\n{STRBUF} went up!"),
        ('sharp_rise',"%s's %s sharply rose!",['Text_BattleEffectActivate','_BattleStatWentWayUpText'],"{USER}'s\n{STRBUF}\rwent way up!"),
        ('fall',"%s's %s fell!",['Text_BattleFoeEffectActivate','_BattleStatFellText'],"{TARGET}'s\n{STRBUF} fell!"),
        ('sharp_fall',"%s's %s sharply fell!",['Text_BattleFoeEffectActivate','_BattleStatSharplyFellText'],"{TARGET}'s\n{STRBUF}\rsharply fell!")]
    for label,source in [('MadeWhirlwind','made a whirlwind!'),('TookSunlight','took in sunlight!'),('LoweredHead','lowered its head!'),
        ('Glowing','is glowing!'),('Flew','flew up high!'),('Dug','dug a hole!')]:
        specs.append((label,'%s '+source,['Text_BattleUser','_Battle'+label+'Text'],'{USER}\n'+source))
    for name,source,parts,expected in specs:
        rows=[by_label[label] for label in parts]
        native=''.join(terminal(row['english']) for row in rows)
        if native!=expected:raise ValueError('stat/charge English assembly identity differs: '+name)
        ident='BattleStatCharge/'+name
        combined={'label':ident,'english':source,'spanish':''.join(terminal(row['spanish']) for row in rows),
            'original_slots':sum((row['original_slots'] for row in rows),[]),
            'spanish_slots':sum((row['spanish_slots'] for row in rows),[])}
        catalog,_=engine_strings({source:'native stat/charge assembly'},[combined])
        if source not in catalog:raise ValueError('stat/charge runtime slots differ: '+name)
        result.append({'label':ident,'english':source,'spanish':catalog[source],'original_slots':[],'spanish_slots':[]})
        proof[ident]={'parts':parts,'native_english':expected,
            'pointers':[{key:row[key] for key in ('label','english_point','spanish_point') if key in row} for row in rows]}
    return result,proof


def bind_weather_messages(records):
    by_label={row['label']:row for row in records};result=[];proof={}
    specs=[('DownpourText','It started to rain!','A downpour\nstarted!{PROMPT}',0),
        ('SandstormHitsText','%s is buffeted by the sandstorm!','The SANDSTORM hits\n{USER}!{PROMPT}',1)]
    for label,source,expected,count in specs:
        row=by_label[label]
        if row['english']!=expected or len(row['original_slots'])!=count:raise ValueError('weather message English identity differs: '+label)
        body=positional_text(terminal(row['spanish']),row['original_slots'],row['spanish_slots']).replace('{ARG:1}','%1$s')
        ident='BattleWeather/'+label
        result.append({'label':ident,'english':source,'spanish':body,'original_slots':[],'spanish_slots':[]})
        proof[ident]={'label':label,'native_english':expected,
            **{key:row[key] for key in ('english_point','spanish_point') if key in row}}
    return result,proof


def bind_prize_messages(records):
    by_label={row['label']:row for row in records};result=[];proof={}
    specs=[('GotMoneyForWinningText','%s got %s%d for winning!','{PLAYER} got ¥{NUM}\nfor winning!{PROMPT}'),
        ('SentSomeToMomText','%s got %s%d\nfor winning!\vSent some to MOM!','{PLAYER} got ¥{NUM}\nfor winning!\vSent some to MOM!{PROMPT}'),
        ('BattleText_PlayerPickedUpPayDayMoney','%s picked up %s%d!','{PLAYER} picked up\n¥{NUM}!{PROMPT}')]
    for label,source,expected in specs:
        row=by_label[label]
        if row['english']!=expected or len(row['original_slots'])!=2:raise ValueError('prize message English identity differs: '+label)
        if row['original_slots'][0]!=('named','PLAYER') or row['original_slots'][1][0]!='number':raise ValueError('prize runtime slot identity differs: '+label)
        if row['spanish'].count('¥')!=1:raise ValueError('prize currency literal differs: '+label)
        body=positional_text(terminal(row['spanish']),row['original_slots'],row['spanish_slots'])
        body=body.replace('%','%%').replace('{ARG:1}','%1$s').replace('{ARG:2}','%3$d').replace('¥','%2$s')
        ident='BattlePrize/'+label
        result.append({'label':ident,'english':source,'spanish':body,'original_slots':[],'spanish_slots':[]})
        proof[ident]={'label':label,'native_english':expected,'currency':'native ¥ literal, runtime argument 2',
            **{key:row[key] for key in ('english_point','spanish_point') if key in row}}
    return result,proof


def bind_held_item_messages(records):
    by_label={row['label']:row for row in records};result=[];proof={}
    specs=[
        ('%s recovered with %s.','BattleText_TargetRecoveredWithItem','{TARGET}\nrecovered with\v{STRBUF}.{PROMPT}'),
        ('A %s rid %s of its confusion.','BattleText_ItemHealedConfusion','A {STRBUF} rid\n{TARGET}\vof its confusion.{PROMPT}'),
        ("%s's\n%s\vactivated!",'BattleText_UsersStringBuffer1Activated',"{USER}'s\n{STRBUF}\vactivated!{PROMPT}")]
    for source,label,expected in specs:
        row=by_label[label]
        if row['english']!=expected or len(row['original_slots'])!=2:
            raise ValueError('held-item English identity differs: '+label)
        text=positional_text(terminal(row['spanish']),row['original_slots'],row['spanish_slots'])
        text=text.replace('%','%%')
        for i,slot in enumerate(row['original_slots'],1):
            kind=slot[0]
            fmt='d' if kind=='number' else 's'
            text=text.replace('{ARG:'+str(i)+'}','%'+str(i)+'$'+fmt)
        ident='BattleHeldItem/'+label
        result.append({'label':ident,'english':source,'spanish':text,'original_slots':[],'spanish_slots':[]})
        proof[ident]={'label':label,'native_english':expected,
            **{key:row[key] for key in ('english_point','spanish_point') if key in row}}
    return result,proof


def battle_message_bindings(records):
    by_label={row['label']:row for row in records};result=[];proof={}
    specs=[('%s fainted!','battle.faint','BattleText_MonFainted','{STRBUF}\nfainted!{PROMPT}'),
        ('%s thawed out!',None,'WasDefrostedText','{USER}\nwas defrosted!{PROMPT}'),
        ('%s is paralyzed! It may be unable to move!',None,'ParalyzedText',"{TARGET}'s\nparalyzed! Maybe\vit can't attack!{PROMPT}"),
        ('%s is hit with recoil!',None,'RecoilText',"{USER}'s\nhit with recoil!{PROMPT}"),
        ('%s is hurt by SPIKES!',None,'BattleText_UserHurtBySpikes',"{USER}'s\nhurt by SPIKES!{PROMPT}"),
        ('%s was badly poisoned!',None,'BadlyPoisonedText',"{TARGET}'s\nbadly poisoned!{PROMPT}"),
        ('%s took the FUTURE SIGHT attack!',None,'BattleText_TargetWasHitByFutureSight','{TARGET}\nwas hit by FUTURE\vSIGHT!{PROMPT}'),
        ('%s was surrounded by SPIKES!',None,'SpikesText','SPIKES scattered\nall around\v{TARGET}!{PROMPT}'),
        ('%s fell asleep!',None,'FellAsleepText','{TARGET}\nfell asleep!{PROMPT}'),
        ('%s was poisoned!',None,'WasPoisonedText','{TARGET}\nwas poisoned!{PROMPT}'),
        ('%s was burned!',None,'WasBurnedText','{TARGET}\nwas burned!{PROMPT}'),
        ('%s was frozen solid!',None,'WasFrozenText','{TARGET}\nwas frozen solid!{PROMPT}'),
        ('%s became confused!',None,'BecameConfusedText','{TARGET}\nbecame confused!{PROMPT}'),
        ('%s is hurt by poison!',None,'HurtByPoisonText','{USER}\nis hurt by poison!{PROMPT}'),
        ('%s is hurt by its burn!',None,'HurtByBurnText',"{USER}'s\nhurt by its burn!{PROMPT}"),
        ('%s is fast asleep!',None,'FastAsleepText','{USER}\nis fast asleep!{PROMPT}'),
        ('%s woke up!',None,'WokeUpText','{USER}\nwoke up!{PROMPT}'),
        ('%s is frozen solid!',None,'FrozenSolidText','{USER}\nis frozen solid!{PROMPT}'),
        ("%s's fully paralyzed!",None,'FullyParalyzedText',"{USER}'s\nfully paralyzed!{PROMPT}"),
        ("%s's confused no more!",None,'ConfusedNoMoreText',"{USER}'s\nconfused no more!{PROMPT}"),
        ("%s's move is no longer disabled!",None,'DisabledNoMoreText',"{USER}'s\ndisabled no more!{PROMPT}"),
        ("%s's SUBSTITUTE broke!",None,'SubFadedText',"{TARGET}'s\nSUBSTITUTE faded!{PROMPT}"),
        ("%s's energy was drained!",None,'SuckedHealthText','Sucked health from\n{TARGET}!{PROMPT}')]
    for source,context,label,expected in specs:
        row=by_label[label]
        if row['english']!=expected or len(row['original_slots'])!=1:raise ValueError('battle binding English identity differs: '+label+'; expected '+repr(expected)+', got '+repr(row['english']))
        text=positional_text(terminal(row['spanish']),row['original_slots'],row['spanish_slots']).replace('{ARG:1}','%1$s')
        ident='BattleBindings/'+label
        result.append({'label':ident,'english':source,'spanish':text,'context':context,'original_slots':[],'spanish_slots':[]})
        proof[ident]={'label':label,'native_english':expected,'engine_source':source,
            **{key:row[key] for key in ('english_point','spanish_point') if key in row}}
    return result,proof


def assemble_battle_texts(records):
    by_label={record['label']:record for record in records}
    specs=[('move','%s\nused %s!',['_ActorNameText','_UsedMove1Text','_MoveNameText','_EndUsedMove1Text']),
        ('experience','%s gained %d EXP. Points!',['Text_Gained','_ExpPointsText']),
        ('boosted_experience','%s gained a boosted %d EXP. Points!',['Text_Gained','_BoostedExpPointsText'])]
    assembled=[];proof={}
    for name,source,parts in specs:
        rows=[by_label[label] for label in parts]
        record={'label':'BattleAssembly/'+name,'english':''.join(terminal(row['english']) for row in rows),
            'spanish':''.join(terminal(row['spanish']) for row in rows),
            'original_slots':sum((row['original_slots'] for row in rows),[]),
            'spanish_slots':sum((row['spanish_slots'] for row in rows),[])}
        if string_shape(record['english'])!=string_shape(source):raise ValueError('battle assembly English identity differs: '+name)
        positional_text(record['spanish'],record['original_slots'],record['spanish_slots'])
        assembled.append(record)
        proof[record['label']]={'parts':parts,'english_source':source,
            'pointers':[{key:row[key] for key in ('label','english_point','spanish_point') if key in row} for row in rows]}
    return assembled,proof


def engine_strings(sources,records):
    def page_fragments(record):
        english=terminal(record['english']).split('\f')
        spanish=terminal(record['spanish']).split('\f')
        if len(english)<2 or len(english)!=len(spanish):return []
        def split_slots(parts,slots):
            counts=[len([m for m in re.findall(r'\{([^}]+)\}',part)
                if m not in ('DONE','PROMPT')]) for part in parts]
            if sum(counts)!=len(slots):return None
            result=[];index=0
            for count in counts:
                result.append(slots[index:index+count]);index+=count
            return result
        original=split_slots(english,record['original_slots'])
        translated=split_slots(spanish,record['spanish_slots'])
        if original is None or translated is None:return []
        fragments=[]
        for start in range(len(english)):
            for end in range(start+1,len(english)+1):
                if start==0 and end==len(english):continue
                old_slots=sum(original[start:end],[]);new_slots=sum(translated[start:end],[])
                old_shape=Counter(slot_marker(slot) for slot in old_slots)
                new_shape=Counter(slot_marker(slot) for slot in new_slots)
                if old_shape!=new_shape:continue
                suffix=f'/page-{start+1}' if end==start+1 else f'/pages-{start+1}-{end}'
                fragments.append({**record,'label':record['label']+suffix,
                    'english':'\f'.join(english[start:end]),'spanish':'\f'.join(spanish[start:end]),
                    'original_slots':old_slots,'spanish_slots':new_slots,'page_fragment':True})
        return fragments

    indexed={};emphasized={}
    for record in records:
        for candidate in [record,*page_fragments(record)]:
            shape=string_shape(candidate['english'])
            indexed.setdefault(shape,[]).append(candidate)
            emphasized.setdefault(shape.casefold(),[]).append(candidate)
    catalog={};proof={}
    for source,where in sources.items():
        formats=[m[0][1:] for m in FORMAT.finditer(source)]
        source_markers=[m[1] for m in re.finditer(r'\{([^}]+)\}',source)
            if m[1] not in ('DONE','PROMPT')]
        source_direct=bool(source_markers) and not formats
        candidates={};labels=[]
        shape=string_shape(source);exact=shape in indexed
        matches=indexed.get(shape,[]) if exact else emphasized.get(shape.casefold(),[])
        if '\f' not in source:
            page_matches=[record for record in matches if record.get('page_fragment')]
            if page_matches:matches=page_matches
        matched_aliases=[]
        if not matches:
            variants=[(source,[])]
            for abbreviated,expanded in ENGINE_TEXT_ABBREVIATIONS:
                for candidate,used in tuple(variants):
                    if abbreviated not in candidate:continue
                    alias=candidate.replace(abbreviated,expanded)
                    if not any(alias==existing for existing,_ in variants):
                        variants.append((alias,used+[abbreviated+' → '+expanded]))
            for candidate,used in variants[1:]:
                alias_matches=indexed.get(string_shape(candidate),[])
                if alias_matches:
                    matches.extend(alias_matches)
                    matched_aliases.extend(used)
        for record in matches:
            if source_direct:
                source_required=Counter(name for name in source_markers
                    if name not in ('PLAYER','RIVAL','DAY'))
                original_markers=Counter(slot_marker(slot) for slot in record['original_slots'])
                original_markers.pop(None,None)
                for optional in ('PLAYER','RIVAL','DAY'):original_markers.pop(optional,None)
                translated_markers=Counter(slot_marker(slot) for slot in record['spanish_slots'])
                translated_markers.pop(None,None)
                for optional in ('PLAYER','RIVAL','DAY'):translated_markers.pop(optional,None)
                if source_required!=original_markers or source_required!=translated_markers:continue
                body=terminal(record['spanish'])
            else:
                if len(formats)!=len(record['original_slots']):continue
                try:body=positional_text(terminal(record['spanish']),record['original_slots'],record['spanish_slots'],
                        preserve_named=record.get('preserve_named',False))
                except ValueError:continue
            body=body.replace('%','%%')
            body=re.sub(r'\{ARG:([0-9]+)\}',lambda m:'%'+m[1]+'$'+formats[int(m[1])-1],body)
            candidates[body]=True;labels.append(record['label'])
        if len(candidates)==1:
            catalog[source]=next(iter(candidates));proof[source]={'engine':where,'labels':sorted(labels)}
            if matched_aliases:
                proof[source]['match']='verified source abbreviation: '+'; '.join(sorted(set(matched_aliases)))
            elif not exact:proof[source]['match']='case-insensitive English emphasis'
    return catalog,proof


def dialogue_engine_records(english,spanish):
    """Expose verified script dialogue as candidates for engine-authored text.

    Gold UI modules sometimes print a literal instead of looking up the script
    label that owns the same line. Pairing against the already-validated
    dialogue catalog reuses the original Spanish wording and page breaks.
    Named runtime substitutions remain tokens; string buffers become
    positional format arguments when the engine call supplies them.
    """
    records=[]
    named={'{PLAYER}','{RIVAL}','{DAY}','{DONE}','{PROMPT}'}
    for ident,original in sorted(english.items()):
        translated=spanish.get(ident)
        if translated is None:continue
        original_tokens=re.findall(r'\{[^}]+\}',terminal(original))
        translated_tokens=re.findall(r'\{[^}]+\}',terminal(translated))
        original_slots=[token[1:-1] for token in original_tokens if token not in named]
        translated_slots=[token[1:-1] for token in translated_tokens if token not in named]
        if Counter(original_slots)!=Counter(translated_slots):continue
        point={'label':'ScriptDialogue/'+ident,'english':original,'spanish':translated,
            'original_slots':original_slots,'spanish_slots':translated_slots,
            'preserve_named':True}
        records.append(point)
        all_original=[token[1:-1] for token in original_tokens if token not in ('{DONE}','{PROMPT}')]
        all_translated=[token[1:-1] for token in translated_tokens if token not in ('{DONE}','{PROMPT}')]
        if all_original!=original_slots or all_translated!=translated_slots:
            records.append({**point,'original_slots':all_original,
                'spanish_slots':all_translated,'preserve_named':False})
    return records


def add_engine_only_ui_translations(catalog,sources):
    """Localize engine-authored interface text absent from the original cart."""
    # These group names are stored as data before being passed to Strings(),
    # so the normal source harvester cannot see their literal call sites.
    for source,line in {
        'BATTLE OPTIONS':'740', 'AUDIO':'745', 'VIDEO':'747',
        'GRAPHICS':'752', 'EXTRAS':'756',
    }.items():
        sources.setdefault(source, f'src/ui/OptionsMenu.lua:{line}')
    # BindingsMenu translates these table values at use time rather than at
    # literal call sites. Keep physical button/key names (A, B, START...) intact.
    if any(where.startswith('src/ui/BindingsMenu.lua:') for where in sources.values()):
        for source,line in {'UP':21,'DOWN':22,'LEFT':23,'RIGHT':24,
                'SPEED -':29,'SPEED +':30}.items():
            sources.setdefault(source,f'src/ui/BindingsMenu.lua:{line}')
    if any(where.startswith('src/ui/PaletteScreen.lua:') for where in sources.values()):
        for source,line in {'FULL COLOUR':126,'SINGLE COLOUR':127,'GREYSCALE':128}.items():
            sources.setdefault(source,f'src/render/Palette.lua:{line}')
    translations={
        'Welcome to the\nUNION ROOM.\fTrainers from\nevery generation\vgather here.\fWould you like\nto go in?':
            'Bienvenido a la\nSALA UNIÓN.\fAquí se reúnen\nentrenadores de\vtodas las generaciones.\f¿Quieres entrar?',
        'STADIUM MODELS':'MODELOS STADIUM', 'BUILDING MODELS':'CREANDO MODELOS',
        'MODELS READY':'MODELOS LISTOS', 'READY':'LISTO', 'BUILD':'CREAR',
        'B:CANCEL':'B:CANCELAR', 'A/B:BACK':'A/B:VOLVER',
        'SELECT:REBUILD':'SELECT:RECREAR',
        'Import Pokemon\nStadium US 1.0 in\nthe launcher MODS\nimports panel.':
            'Importa Stadium\nUS 1.0 en IMPORTS\ndel mod desde el\nlanzador.',
        'Model build failed.\nCheck free storage\nand import again.':
            'No se pudieron\ncrear los modelos.\nRevisa el espacio\nVuelve a importar.',
        '      DIRECTOR':'      DIRECCIÓN',
        '    PROGRAMMING':'    PROGRAMACIÓN',
        '   ENGINE DESIGN':'   DISEÑO MOTOR',
        '   BATTLE ENGINE':'   MOTOR DE BATALLA',
        '   SCRIPT ENGINE':'   MOTOR DE GUION',
        '    WORLD ENGINE':'    MOTOR DEL MUNDO',
        '    AUDIO ENGINE':'    MOTOR DE AUDIO',
        '      GRAPHICS':'      GRÁFICOS',
        '   USER INTERFACE':'   INTERFAZ USUARIO',
        '    ROM IMPORTER':'    IMPORTAR ROM',
        '    SAVE EDITOR':'    EDITOR DE PART.',
        '      MOD SDK':'      SDK DE MODS',
        '       TOOLS':'       HERRAMIENTAS',
        '      TESTING':'      PRUEBAS',
        '     BUILT WITH':'     CREADO CON',
        '      BASED ON':'      BASADO EN',
        '   SPECIAL THANKS':'  AGRADECIMIENTOS',
        '      PRODUCER':'      PRODUCCIÓN',
        '    GOLD VERSION':'    VERSIÓN ORO',
        '   SILVER VERSION':'   VERSIÓN PLATA',
        '  CRYSTAL VERSION':'  VERSIÓN CRISTAL',
        '     PORT STAFF':'     EQUIPO DEL MOD',
        'a fan-made port':'un port de fans',
        'THE END':'EL FIN',
        'Touch Controls':'Controles táctiles', 'Reset':'Reiniciar', 'Done':'Listo',
        'On-screen controls':'Controles en pantalla', 'Skin':'Apariencia',
        'Export':'Exportar', 'Disable':'Desactivar', 'Enable':'Activar',
        'Landscape':'Horizontal', 'Portrait':'Vertical',
        'Built-in pad':'Mando integrado', '%s (%d pages)':'%s (%d páginas)',
        'Button size (%s)':'Tamaño de botones (%s)',
        'Export failed: %s':'Error al exportar: %s',
        'Exported to %s in your save folder.':'Exportado a %s en la carpeta de partidas.',
        ' %d image(s) were missing and left out.':' Faltaban %d imágenes y se omitieron.',
        'Controls are hidden in-game. Enable them to show and edit the layout.':
            'Los controles están ocultos durante el juego. Actívalos para mostrarlos y editar su distribución.',
        'This skin owns its own art, hitboxes and screen position, so size and dragging are off. Drop a RetroArch overlay folder or .zip into the skins folder of your save directory to add more.':
            'Esta apariencia define sus imágenes, zonas táctiles y posición de pantalla, por lo que no permite cambiar el tamaño ni arrastrar botones. Añade una carpeta de controles de RetroArch o un archivo .zip a la carpeta skins de tus partidas para instalar más.',
        'Drag each button to reposition, -/+ to resize. Portrait and landscape are saved separately when you tap Done.':
            'Arrastra cada botón para moverlo y usa -/+ para cambiar su tamaño. Las distribuciones vertical y horizontal se guardan por separado al pulsar Listo.',
        'FULL COLOUR':'A TODO COLOR', 'SINGLE COLOUR':'UN SOLO COLOR',
        'GREYSCALE':'ESCALA DE GRISES',
        'UP':'ARRIBA', 'DOWN':'ABAJO', 'LEFT':'IZQ.', 'RIGHT':'DER.',
        'SPEED -':'VELOC. -', 'SPEED +':'VELOC. +',
        'EXIT GAME':'SALIR DEL JUEGO',
        'NO SAVE FILE':'SIN PARTIDA',
        'EXT ONLY':'SOLO EXT.',
        'GAME ONLY':'SOLO JUEGO',
        'BOTH':'AMBOS',
        'FIT':'AJUSTAR',
        'OUT%d':'ALEJAR%d',
        'IN%d':'ACERCAR%d',
        'FULL':'COMPLETA',
        'WINDOWED':'VENTANA',
        'DISPLAY':'PANTALLA',
        'DISPLAY (%dHZ)':'PANTALLA (%dHZ)',
        'UNAVAILABLE':'NO DISP.',
        'EXTENDED':'AMPLIADO',
        'STANDARD':'ESTÁNDAR',
        # The merged engine's options screen has many rows and values that
        # were never present in the Gold ROM. Keep them in the ROM-derived
        # catalog anyway, with explicit provenance, so the Spanish mod also
        # covers the emulator controls exposed while playing Gold.
        '%d INSTALLED':'%d INSTALADOS',
        '%d OPTIONS':'%d OPCIONES',
        '%dX':'%dX',
        'AUDIO MODE':'MODO DE AUDIO',
        'BATTLE OPTIONS':'OPCIONES COMBATE',
        'AUDIO':'AUDIO',
        'VIDEO':'VÍDEO',
        'GRAPHICS':'GRÁFICOS',
        'EXTRAS':'OTROS',
        'AUTO (FILL HUD)':'AUTO (HUD COMPLETO)',
        'BACK':'ATRÁS',
        'BATTLE ANIMATION':'ANIMACIÓN COMBATE',
        'BATTLE BG':'FONDO COMBATE',
        'BATTLE HUD':'HUD COMBATE',
        'BATTLE LAYOUT':'DISEÑO COMBATE',
        'BATTLE SIZE':'TAMAÑO COMBATE',
        'BATTLE SPEED':'VEL. COMBATE',
        'BLACK':'NEGRO',
        'CENTERED':'CENTRADO',
        'COLORS':'COLORES',
        'CONTROLS':'CONTROLES',
        'DATE FORMAT':'FORMATO FECHA',
        'DYNAMIC':'DINÁMICO',
        'FAITHFUL RATIO':'PROPORCIÓN ORIGINAL',
        'FILL':'RELLENAR',
        'FIXED':'FIJO',
        'KEY BAR':'BARRA RÁPIDA',
        'LOGIC CLOCK':'RELOJ LÓGICO',
        'MAX FPS':'FPS MÁXIMOS',
        'MENU SPEED':'VEL. MENÚ',
        'MODS':'MODS',
        'MUSIC FILTER':'FILTRO MÚSICA',
        'MUSIC VOL':'VOL. MÚSICA',
        'OG':'ORIGINAL',
        'ORIENTATION':'ORIENTACIÓN',
        'OVERWORLD SPEED':'VEL. MAPA',
        'PERFORMANCE':'RENDIMIENTO',
        'PIKACHU VOL':'VOL. PIKACHU',
        'RULESET':'REGLAS',
        'SCREEN POS':'POSICIÓN PANTALLA',
        'SFX VOL':'VOL. EFECTOS',
        'SHADER FX':'EFECTOS GRÁFICOS',
        'SHADER FX 2':'EFECTOS GRÁFICOS 2',
        'TILT':'INCLINACIÓN',
        'TIME FORMAT':'FORMATO HORA',
        'TOUCH PAD':'CONTROLES TÁCTILES',
        'UI LAYOUT':'DISEÑO INTERFAZ',
        'UI LETTERBOX':'BORDES INTERFAZ',
        'VIBRATION':'VIBRACIÓN',
        'VIDEO MODE':'MODO VÍDEO',
        'VOID FILL':'RELLENO BORDES',
        'VSYNC':'SINC. VERTICAL',
        'WHITE':'BLANCO',
        'WIDE':'PANORÁMICO',
        'WORLD':'MUNDO',
        'ZOOM':'ZOOM',
        # Gold's port-added graphics and handheld controls are exposed on
        # the actual Gen 2 OPTIONS screen as well as the shared screen.
        'ADAPTIVE':'ADAPTATIVA',
        'AMBER':'ÁMBAR',
        'AUTO':'AUTOMÁTICO',
        'BALANCED':'EQUILIBRADO',
        'BLUE':'AZUL',
        'BROWN':'MARRÓN',
        'CENTER':'CENTRO',
        'CLASSIC':'CLÁSICO',
        'COLOR':'COLOR',
        'CYAN':'CIAN',
        'DMG':'DMG',
        'FADE ':'DESVAN. ',
        'FILL ':'RELLENAR',
        'GAME SPEED':'VELOCIDAD JUEGO',
        'GEN 2':'GEN. 2',
        'GREEN':'VERDE',
        'HIGH':'ALTO',
        'INDIGO':'ÍNDIGO',
        'LIGHT':'SUAVE',
        'LIME':'LIMA',
        'LOW':'BAJO',
        'MAGENTA':'MAGENTA',
        'MINT':'MENTA',
        'OG  ':'ORIGINAL',
        'OLIVE':'OLIVA',
        'ORANGE':'NARANJA',
        'PALETTE':'PALETA',
        'PURPLE':'MORADO',
        'RED':'ROJO',
        'ROSE':'ROSA',
        'SAND':'ARENA',
        'SILVER':'PLATEADO',
        'SKIN':'CONTROLES',
        'STRONG':'FUERTE',
        'TEAL':'VERDE AZULADO',
        'TOP':'ARRIBA',
        'TOUCH LAYOUT':'DISEÑO TÁCTIL',
        'TREES':'ÁRBOLES',
        'UPPER':'SUPERIOR',
        '1X':'1X', '2X':'2X', '3X':'3X', '4X':'4X',
    }
    proof={}
    for source,translated in translations.items():
        if source not in sources:continue
        catalog[source]=translated
        proof[source]={'engine':sources[source],
            'translation':translated,
            'note':'engine-added UI; no original Gold ROM equivalent'}
    return proof


def add_engine_gen2_literal_translations(catalog,sources):
    """Translate fixed Gen 2 interface literals whose UI bypasses ROM labels."""
    badge_names={
        'ZEPHYR':'CÉFIRO', 'HIVE':'COLMENA', 'PLAIN':'PLANICIE',
        'FOG':'NIEBLA', 'STORM':'TORMENTA', 'MINERAL':'MINERAL',
        'GLACIER':'GLACIAR', 'RISING':'DRAGÓN',
        'BOULDER':'ROCA', 'CASCADE':'CASCADA', 'THUNDER':'TRUENO',
        'RAINBOW':'ARCOÍRIS', 'SOUL':'ALMA', 'MARSH':'PANTANO',
        'VOLCANO':'VOLCÁN', 'EARTH':'TIERRA',
    }
    translations={
        # Union battle results are port-authored, not original cartridge text.
        'You won the\nbattle!':'¡Has ganado\nel combate!',
        'You lost the\nbattle.':'Has perdido\nel combate.',
        'The battle was\na draw.':'El combate acabó\nen empate.',
        'The games fell\nout of step.':'Las partidas\nse desincronizaron.',
        'The link was\nlost.':'Se ha perdido\nla conexión.',
        'The battle could\nnot go on.':'El combate no\npudo continuar.',
        'CLOCK':'RELOJ', 'MAP':'MAPA', 'PHONE':'TELÉFONO', 'RADIO':'RADIO',
        'AM':'A. M.', 'PM':'P. M.',
        'Whom do you want to call?':'¿A quién quieres\nllamar?',
        "You're out of the service area.":'Estás fuera del área de servicio.',
        'Press any button to exit.':'Pulsa cualquier botón para salir.',
        'Delete this stored phone number?':'¿Borrar este número guardado?',
        'Huh? Sorry, wrong number!':'¿Eh? ¡Perdona, número equivocado!',
        'That number is out of the area.':'Ese número está fuera del área.',
        'Just go talk to that person!':'¡Ve a hablar con esa persona!',
        'CALL':'LLAMAR', 'DELETE':'BORRAR', 'NO CARD DATA':'SIN DATOS',
        'ID No':'N.° ID', 'NAME/':'NOMBRE/',
        'KANTO BADGES':'MEDALLAS DE KANTO', 'JOHTO BADGES':'MEDALLAS DE JOHTO',
        'OPTION':'OPCIÓN', 'SEARCH':'BUSCAR', 'NEW':'NUEVO', 'OLD':'ANTIGUO',
        'A-Z':'A-Z', 'TYPE1':'TIPO 1', 'TYPE2':'TIPO 2',
        'BEGIN SEARCH!!':'¡INICIAR BÚSQUEDA!',
        'The specified type\nwas not found.':'No se ha encontrado\nel tipo indicado.',
        'NEW POKéDEX MODE':'NUEVO MODO POKÉDEX',
        '<PK><MN> are listed by':'Los POKéMON se ordenan por',
        'evolution type.':'tipo de evolución.',
        'OLD POKéDEX MODE':'ANTIGUO MODO POKÉDEX',
        'official type.':'tipo oficial.',
        '<PK><MN> are listed':'Los POKéMON se ordenan',
        'alphabetically.':'alfabéticamente.',
        'A to Z MODE':'ORDEN ALFABÉTICO',
        'UNOWN MODE':'MODO UNOWN',
        'UNOWN are listed':'UNOWN se ordena',
        'in catching order.':'según el orden de captura.',
        'There is a POKéMON\nholding MAIL.':'Hay un POKéMON\nque lleva una CARTA.',
        'Please remove the\nMAIL.':'Quítale la\nCARTA, por favor.',
        'Could not save.':'No se pudo guardar.',
        'Which BOX?':'¿Qué CAJA?',
        'TM32':'MT32', 'TM29':'MT29', 'TM15':'MT15', 'TM25':'MT25',
        'TM14':'MT14', 'TM38':'MT38',
        "Oh? You don't have\na COIN CASE.":'¡Vaya! No tienes\nun MONEDERO.',
        'With %s,\nwhat\'ll you do?':'¿Qué quieres hacer\ncon %s?',
        '%s is\nbusy right now.':'%s está\nocupado ahora mismo.',
        'Waiting for\n%s…':'Esperando a\n%s…',
        '%s said no.':'%s ha dicho que no.',
        '%s didn\'t\nanswer.':'%s no ha\nrespondido.',
        '%s left the\nUNION ROOM.':'%s ha salido de\nla SALA UNIÓN.',
        '%s can\'t do\nthat right now.':'%s no puede\nhacerlo ahora.',
        '%s wants\nto battle. OK?':'¿%s quiere\ncombatir?',
        '%s wants\nto trade. OK?':'¿%s quiere\nintercambiar?',
        '%s is playing\n%s.\fImport %s\nto see them here.':'%s está jugando\na %s.\fImporta %s\npara verlo aquí.',
        '%s cancelled.':'%s ha cancelado.',
        'CONFUSED':'CONFUSO', 'Enemy':'RIVAL', 'Your':'TU',
        '%s BED':'CAMA %s', '%s CARPET':'ALFOMBRA %s',
        '%s POSTER':'PÓSTER DE %s', '%s DOLL':'MUÑECO %s',
        'BIG %s':'%s GRANDE',
        ' fell asleep!':' se durmió!', ' was poisoned!':' fue envenenado!',
        ' is hurt by poison!':' sufre daño por veneno!',
        ' was badly poisoned!':' fue gravemente envenenado!',
        ' is paralyzed! It may be unable to move!':' está paralizado; puede que no se mueva!',
        ' was burned!':' se quemó!',
        ' is hurt by its burn!':' sufre daño por la quemadura!',
        ' was frozen solid!':' fue congelado!',
        ' became confused!':' está confuso!',
        'You have no more POKéMON!':'¡No te quedan más POKéMON!',
        'Linking up with\n%s…':'Conectando con\n%s…',
        'Getting ready to\nbattle %s…':'Preparándose para\ncombatir contra %s…',
        'Getting ready to\ntrade with %s…':'Preparándose para\nintercambiar con %s…',
        'Connecting to the\nUNION ROOM…':'Conectando a la\nSALA UNIÓN…',
        'Couldn\'t connect.\fNo other trainers\ncan be seen now.':'No se pudo conectar.\fNo se ven otros\nentrenadores.',
        'The UNION ROOM\nserver is too old.\fNo other trainers\ncan be seen now.':'El servidor de la\nSALA UNIÓN es antiguo.\fNo se ven otros\nentrenadores.',
        'This game is too\nold to link up.\fUpdate it to meet\nother trainers.':'Este juego es muy\nantiguo para conectarse.\fActualízalo para\nconocer entrenadores.',
        'Couldn\'t enter\nthe UNION ROOM.\fNo other trainers\ncan be seen now.':'No se pudo entrar en\nla SALA UNIÓN.\fNo se ven otros\nentrenadores.',
        'The link was lost.\nReconnecting…':'Se perdió el enlace.\nReconectando…',
        'Couldn\'t link up\nagain.\fNo other trainers\ncan be seen now.':'No se pudo restablecer\nel enlace.\fNo se ven otros\nentrenadores.',
        'Your games can\'t\nlink up for this.':'Tus juegos no\npueden conectarse.',
        "I'm sorry, the\nUNION ROOM isn't\vopen to you yet.":'Lo siento, la\nSALA UNIÓN aún no\vestá abierta.',
        "You'll need at\nleast one POKéMON\vto go in.":'Necesitas al menos\nun POKéMON\vpara entrar.',
        'Your game will be\nsaved before you\vgo in. OK?':'Se guardará la partida\nantes de entrar. ¿Vale?',
        'Please come\nback anytime.':'Vuelve cuando\nquieras.',
        'Your POKéMON are\nall rested.\fRight this way.':'Tus POKéMON están\nrecuperados.\fPor aquí, por favor.',
        'PARTY <PK><MN>':'EQUIPO <PK><MN>', 'BOX%d':'CAJA%d',
        'Saving… Leave ON!':'Guardando… ¡No apagues!',
        'No save.':'No hay partida guardada.',
        'There is no POKéMON there.':'No hay ningún POKéMON ahí.',
        "It's already there.":'Ya está ahí.',
        "You'll need a\nPOKéMON to call\fwith.":'Necesitas un POKéMON\fpara llamar.',
        'What?\n%s?':'¿Qué?\n¿%s?',
        'Whoa!\n%d min.?':'¡Vaya!\n¿%d min.?',
        "%s!\nIt's so dark!":'¡%s!\n¡Qué oscuro está!',
        '%s!\nI overslept!':'¡%s!\n¡Me he dormido!',
        '%s!\nYikes! I over-\nslept!':'¡%s!\n¡Vaya! Me he\nquedado dormido.',
        '%s, is that right?':'¿%s, es correcto?',
        "%s o'clock":'%s en punto', '%d min.':'%d min.',
        'MORN':'MAÑANA', 'DAY':'DÍA', 'NITE':'NOCHE',
        'POKé BALLS':'POKé BALLS', 'KEY ITEMS':'OBJ. CLAVE', 'TM/HM':'MT/MO',
        'You now have\n%d points.':'Ahora tienes\n%d puntos.',
        'There was a trophy\ninside!\f{PLAYER} sent the\ntrophy home.':'¡Había un trofeo\ndentro!\f{PLAYER} lo envió\na casa.',
        ' ALPH RUINS STAMP':' SELLO RUINAS ALFA', 'Do what?':'¿Qué harás?',
        'VACANT':'VACÍO', 'A▶PRINT':'A▶IMPR.', 'B▶CANCEL':'B▶CANC.',
        'L▶BEFORE':'L▶ANT.', 'R▶NEXT':'R▶SIG.',
        'Play with\n3 coins?':'¿Apostar 3\nfichas?',
        'Place\nyour bet':'Haz tu\napuesta.',
        'The cards\nshuffled.':'Barajadas las\ncartas.', 'Darn…':'¡Fallé…!',
        "Excuse me.\nYou're not ready.":'Perdona.\nAún no estás listo.',
        'Only three POKéMON\nmay be entered.':'Solo se admiten tres\nPOKéMON.',
        'The {STRBUF} POKéMON\nmust all be different kinds.':'Los {STRBUF} POKéMON\ndeben ser de especies distintas.',
        'The {STRBUF} POKéMON\nmust not hold the same items.':'Los {STRBUF} POKéMON\nno pueden llevar el mismo objeto.',
        "You can't take an\nEGG!":'¡No puedes llevar\nHUEVOS!',
        "Please return when\nyou're ready.":'Vuelve cuando\nestés preparado.',
        'Challenge':'RETO', 'Explanation':'EXPLICACIÓN',
        'What level do you\nwant to challenge?':'¿A qué nivel quieres\ncompetir?',
        'A party POKéMON\ntops this level.':'Un POKéMON de tu equipo\nsupera este nivel.',
        '%s may go\nonly to BATTLE\n\nROOMS that are\nLv.70 or higher.':'Solo se permite a\n%s combatir en SALAS\nDE COMBATE de nivel\n70 o superior.',
        'Cancel your BATTLE\nROOM challenge?':'¿Cancelar tu reto de\nla SALA DE COMBATE?',
        'You have no more\nPOKéMON that can\vfight!':'¡No te quedan\nPOKéMON que puedan\vluchar!',
        "%s was sent to BILL's PC.":'%s fue enviado\nal PC de BILL.',
        "That isn't going to help here.":'Eso no servirá aquí.',
        'NO BATTLE':'SIN COMBATE',
        'Installed\nadd-ons':'Complementos\ninstalados',
        'Return to\nthe title':'Volver al\ntítulo',
        'Return to the\ntitle screen?':'¿Volver a la\npantalla de título?',
        'Boy':'CHICO', 'Girl':'CHICA',
        'Are you a boy?\nOr are you a girl?':'¿Eres un chico?\n¿O eres una chica?',
        'lower':'minús.', 'DEL':'BORR', 'END':'FIN', 'UPPER':'MAYÚS.',
        'READ MAIL':'LEER CARTA', 'PUT IN PACK':'A LA MOCHILA',
        'ATTACH MAIL':'ADJUNTAR CARTA',
        'SAVED':'AHORRADO', 'HELD':'EN MANO',
        'This certifies':'Se certifica', 'completed the':'completado la',
        'new #DEX.':'nueva #DEX.',
        'RIGHT SIDE':'LADO DERECHO', 'LEFT SIDE':'LADO IZQUIERDO',
        'POKéMON Channel':'Canal POKéMON', 'Where?':'¿Dónde?',
        'Fly to %s?':'¿Volar a %s?', 'START>CANCEL':'START>CANCELAR',
        ' STOCK <PK><MN> ':' RESERVA <PK><MN> ',
        ' THIS <PK><MN> ':' ACTUAL <PK><MN> ',
        'ATTK/':'POT.', '<ID>№.':'ID N.°',
        'RING!…RING!…\n%s':'¡Riiin!… ¡Riiin!…\n%s',
        'Points':'PUNTOS', 'Now on:':'Ahora en:', 'TAKE':'TOMAR',
        'The battle could not start.':'No se pudo iniciar\nel combate.',
        '1, 2 and…\x01 Poof!\x01\f%s forgot\n%s.\fAnd…\f%s learned\n%s!':
            '¡1, 2 y…\x01 ¡Puf!\x01\f%1$s olvidó\n%2$s.\fY…\f%3$s aprendió\n%4$s!',
        "%s can't learn %s!":'¡%1$s no puede aprender %2$s!',
        '{PLAYER} used the\n%s.':'{PLAYER} usó\n%s.',
        'There was a trophy\ninside!\fThe trophy was\nsent home.':
            '¡Había un trofeo\ndentro!\fEl trofeo se\nenvió a casa.',
        "Items can't be used in a link battle!":'No se pueden usar objetos en un combate por cable.',
        'No running from a link battle!':'¡No puedes huir de un combate por cable!',
        '%s ran from the battle!':'¡%s huyó del combate!',
        '%s left the battle.':'%s abandonó el combate.',
        '%s ran out of time!':'¡A %s se le acabó el tiempo!',
        "Time's up! You forfeit the match.":'¡Se acabó el tiempo! Has perdido el combate.',
        'The match ended.':'El combate ha terminado.',
        'Saved to\n%s.':'Guardado en\n%s.',
        'Saved as\n%s\vin the save\nfolder.':'Guardado como\n%s\ven la carpeta\nde partidas.',
        'SELECT:CLEAR ROW\nSTART:RESET ALL':'SELECT:BORRA FILA\nSTART:REIN. TODO',
        'RESET ALL BINDINGS?':'¿REINICIAR CONTROLES?',
        'PRESS A BUTTON':'PULSA UN BOTÓN',
        'RELEASE TO SET':'SUELTA PARA FIJAR',
        'ESC/2ND CANCELS':'ESC/2.° CANCELA',
        'TOUCH B CANCELS':'B TÁCTIL CANCELA',
        'COLOUR':'COLOR', 'MONOCHROME':'MONOCROMO',
        'CONVERT':'CONVERTIR', 'UPDATE':'ACTUALIZAR',
        'DOWNLOAD SHADERS':'DESCARGAR SHADERS',
        'SELECT:EDIT PARAMS':'SELECT:AJUSTES',
        '...':'...', 'UP TO DATE':'ACTUALIZADO', 'FAILED':'ERROR',
        'Update the app':'Actualiza la app',
        'Reinstall the app':'Reinstala la app',
        'A/L/R:STEP\nSELECT:RESET  START:ALL':'A/L/R:PASO\nSEL:REIN. INI:TODO',
        'RESET ALL PARAMS?':'¿REINICIAR AJUSTES?',
        '%s wants to\nlearn %s!':'¡%s quiere\naprender %s!',
        '%s already knows %s!':'¡%1$s ya conoce %2$s!',
        'HEALTH':'PS', 'HP':'PS',
        '%s\nfainted!':'¡%s\ndebilitado!',
        'Gold cache incomplete:\n%s':'Faltan datos de Gold:\n%s',
        'Font load failed:\n%s':'Error al cargar la fuente:\n%s',
        '%s is missing.\nRe-import the Gold ROM.':'Falta %s.\nReimporta la ROM de Gold.',
        'Failed to boot %s:\n%s':'No se pudo iniciar %s:\n%s',
        '%s DST,\nis that OK?':'%s (H. VERANO),\n¿es correcto?',
        '%s,\nis that OK?':'%s,\n¿es correcto?',
        'This Bug-Catching\nContest winner is\f%s,\nwho caught a\n%s!':'El ganador del\nConcurso de Captura\fde Bichos es %s,\nque atrapó a un\n%s.',
        "OK, I'll take care\nof your money.\f…":'Vale, me ocuparé\nde tu dinero.\f…',
    }
    proof={}
    status_suffix_labels={
        ' fell asleep!':'FellAsleepText', ' was poisoned!':'WasPoisonedText',
        ' was badly poisoned!':'BadlyPoisonedText',
        ' is paralyzed! It may be unable to move!':'ParalyzedText',
        ' was burned!':'WasBurnedText', ' was frozen solid!':'WasFrozenText',
        ' became confused!':'BecameConfusedText',
        ' is hurt by poison!':'HurtByPoisonText',
        ' is hurt by its burn!':'HurtByBurnText',
    }
    for source,where in sources.items():
        # UPPER is only used by the mail keyboard's case toggle in this
        # engine. Its previous generic value described position, not case.
        if source=='UPPER' and catalog.get(source)=='SUPERIOR':
            catalog[source]=translations[source]
            proof[source]={'engine':where,
                'note':'Corrects a misleading generic translation; this engine literal labels the mail keyboard uppercase toggle.'}
            continue
        badge=badge_names.get(source) if where.startswith('src/ui/gen2/TrainerCard.lua:') else None
        if source in catalog or (source not in translations and badge is None):continue
        catalog[source]=badge if badge is not None else translations[source]
        note=('Spanish Johto/Kanto badge name; the Trainer Card stores this as an engine literal.'
            if badge is not None else
            'Spanish translation of an engine-authored Gold UI literal; no direct ROM text binding is exposed.')
        proof[source]={'engine':where,'note':note}
        if source in status_suffix_labels:
            proof[source]={'engine':where,'labels':[status_suffix_labels[source]],
                'note':'Status suffix adapted from the corresponding verified Spanish Gold battle text for the engine status API.'}
        if source=="Oh? You don't have\na COIN CASE.":
            proof[source]={'engine':where,'labels':['ScriptDialogue/57:6b9a'],
                'match':'verified Spanish ROM variant selected from two equivalent English originals',
                'note':'Uses the Spanish dialogue paired with script 57:6b9a; a second original script uses a different article.'}
        card_flip_labels={
            'Play with\n3 coins?':'_CardFlipPlayWithThreeCoinsText',
            'Place\nyour bet':'_CardFlipPlaceYourBetText',
            'The cards\nshuffled.':'_CardFlipShuffledText',
            'Darn…':'_CardFlipDarnText',
        }
        if source in card_flip_labels:
            proof[source]={'engine':where,'labels':[card_flip_labels[source]],
                'note':'Reuses the matching verified original Spanish Gold ROM text.'}
        if source=="%s was sent to BILL's PC.":
            proof[source]={'engine':where,'labels':['_BallSentToPCText'],
                'note':'Adapted from the verified Spanish Gold PC transfer message.'}
        if source=='This Bug-Catching\nContest winner is\f%s,\nwho caught a\n%s!':
            proof[source]={'engine':where,'labels':['_ContestJudging_FirstPlaceText'],
                'note':'Reuses the verified Spanish Gold contest winner text with runtime name buffers.'}
        if source=='%s\nfainted!':
            proof[source]={'engine':where,'labels':['_PoisonFaintText'],
                'note':'Reuses the verified Spanish Gold overworld poison faint message.'}
    if '%s fainted!' in sources:
        context_key='battle.faint|%s fainted!'
    else:
        context_key=None
    if context_key and context_key not in catalog:
        catalog[context_key]='¡%s\nse debilitó!'
        proof[context_key]={'engine':sources['%s fainted!'],
            'labels':['BattleText_MonFainted'],
            'match':'context binding selects the verified Gold faint message used by Battle:announcePlayerFaint',
            'note':'The same English source has a second original Spanish variant for poison fainting; the battle.faint context selects the battle faint line.'}
    return proof


def harvest_engine_sources(engine):
    """Use the engine's own translation harvester and Lua literal parser."""
    spec=importlib.util.spec_from_file_location('spanish_modkit',engine/'tools/modkit.py')
    module=importlib.util.module_from_spec(spec);sys.modules[spec.name]=module;spec.loader.exec_module(module)
    entries=module.harvest_engine_strings(str(engine))
    # The engine harvester deduplicates by literal before generation filtering.
    # Prefer a native Gen 2 owner when the same key appeared first in Gen 1;
    # otherwise the Gold coverage audit silently misses shared words.
    native_seen=set()
    quoted=r'''(?:"(?:[^"\\]|\\.)*"|'(?:[^'\\]|\\.)*')'''
    expression=quoted+r'(?:\s*\.\.\s*'+quoted+r')*'
    calls=re.compile(r'\bStrings(?:\.source)?\(\s*('+expression+r')\s*(?:,|\))')
    fallbacks=re.compile(r'\bRomText\([^,\n]+,\s*'+quoted+r'\s*,\s*('+expression+r')\s*(?:,|\))')
    for source in sorted((engine/'src').rglob('*.lua')):
        relative=source.relative_to(engine).as_posix()
        if '/gen2/' not in relative:continue
        body=source.read_text()
        for match in [*calls.finditer(body),*fallbacks.finditer(body)]:
            literal=match.group(1)
            if literal not in native_seen:
                native_seen.add(literal)
                entries.append((literal,relative+':'+str(body.count('\n',0,match.start())+1)))
    # Runtime menus supplied by this voxel mod also display while GOLD_ES
    # is active. Harvest their literals with the engine's same parser.
    seen={literal for literal,_ in entries}
    root=Path(__file__).resolve().parents[2]
    for relative in ('lib/StadiumImport.lua',):
        body=(root/relative).read_text()
        for match in module.STRINGS_CALL.finditer(body):
            literal=match.group(1)
            if literal.startswith("'"):
                literal='"'+literal[1:-1].replace('"','\\"')+'"'
            if literal not in seen:
                seen.add(literal)
                entries.append((literal,'voxel_mod/'+relative+':'+str(body.count('\n',0,match.start())+1)))
    with tempfile.TemporaryDirectory() as tmp:
        script=Path(tmp)/'strings.lua'
        script.write_text('package.path='+lua_string(str(engine)+'/?.lua;')+'..package.path\nlocal J=require("src.link.Json")\nlocal entries={\n'+''.join('['+literal+']='+lua_string(where)+',\n' for literal,where in entries)+'}\nio.write(J.encode(entries))\n')
        result=subprocess.run(['luajit',str(script)],check=True,capture_output=True,text=True)
    return json.loads(result.stdout)




def extract_landmark_names(en,es,manifest,english,spanish):
    bank,address=manifest['symbols']['Landmarks'];order=manifest['constants']['landmarkOrder']
    source=offset(bank,address);size=4*len(order);positions=[4*i+j for i in range(len(order)) for j in (0,1)]
    cursor=0;candidates=[]
    while True:
        cursor=es.find(en[source:source+2],cursor)
        if cursor<0:break
        if cursor//0x4000>0 and cursor%0x4000+size<=0x4000 and all(es[cursor+i]==en[source+i] for i in positions):
            candidates.append(cursor)
        cursor+=1
    if len(candidates)!=1:raise ValueError('landmark coordinate table identity is not unique')
    target=candidates[0];sb=target//0x4000;sa=target%0x4000+0x4000
    names={};proof={'table':{'english':key((bank,address)),'spanish':key((sb,sa))},'names':{}}
    for index,ident in enumerate(order):
        a=(bank,word(en,bank,address+index*4+2));b=(sb,word(es,sb,sa+index*4+2))
        original,_=name_record(en,*a,english,64);translated,_=name_record(es,*b,spanish,64)
        names[ident]=translated.replace('<BSP>','\n')
        proof['names'][ident]={'english':key(a),'spanish':key(b),'source':original.replace('<BSP>','\n')}
    return names,proof


def tile_png(raw,width,height):
    if width%8 or height%8 or len(raw)!=width*height//4:
        raise ValueError('2bpp dimensions/payload differ')
    pixels=bytearray([255])*(width*height)
    for tile in range(len(raw)//16):
        tx=(tile%(width//8))*8;ty=(tile//(width//8))*8
        for y in range(8):
            low,high=raw[tile*16+y*2:tile*16+y*2+2]
            for x in range(8):
                shade=((low>>(7-x))&1)+2*((high>>(7-x))&1)
                pixels[(ty+y)*width+tx+x]=255-shade*85
    def chunk(name,payload):
        return struct.pack('>I',len(payload))+name+payload+struct.pack('>I',zlib.crc32(name+payload))
    rows=b''.join(b'\0'+pixels[y*width:(y+1)*width] for y in range(height))
    return (b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',width,height,8,0,0,0,0))
            +chunk(b'IDAT',zlib.compress(rows,9))+chunk(b'IEND',b''))


def font_png(raw,width,height):
    if width%8 or height%8 or len(raw)!=width*height//8:
        raise ValueError('1bpp font dimensions/payload differ')
    pixels=bytearray(width*height*2)
    for tile in range(len(raw)//8):
        tx=tile%(width//8)*8;ty=tile//(width//8)*8
        for y in range(8):
            for x in range(8):
                pixels[((ty+y)*width+tx+x)*2+1]=255 if raw[tile*8+y]&(1<<(7-x)) else 0
    def chunk(name,payload):
        return struct.pack('>I',len(payload))+name+payload+struct.pack('>I',zlib.crc32(name+payload))
    rows=b''.join(b'\0'+pixels[y*width*2:(y+1)*width*2] for y in range(height))
    return (b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',width,height,8,4,0,0,0))
            +chunk(b'IDAT',zlib.compress(rows,9))+chunk(b'IEND',b''))


def font_transform(original,translated):
    if len(original)!=1024 or len(translated)!=1024:raise ValueError('font transform needs 128 tiles')
    rows=[]
    for tile in range(128):
        old=original[tile*8:(tile+1)*8];new=translated[tile*8:(tile+1)*8]
        if old!=new:
            rows.append('  {'+str(tile)+', {'+','.join(map(str,old))+'}, {'+','.join(map(str,new))+'}},')
    return """-- Original Spanish Gold glyph differences; generated from verified ROMs.
local changes = {
"""+'\n'.join(rows)+"""
}
return function(ctx)
  local image=ctx.readImage('fonts/font.png')
  local w,h=image:getDimensions()
  assert(w==128 and h==64,'Spanish font requires the Gold base font')
  for _,change in ipairs(changes) do
    local tx=(change[1]%16)*8
    local ty=math.floor(change[1]/16)*8
    for y=0,7 do
      for x=0,7 do
        local divisor=2^(7-x)
        local before=math.floor(change[2][y+1]/divisor)%2
        local after=math.floor(change[3][y+1]/divisor)%2
        local _,_,_,alpha=image:getPixel(tx+x,ty+y)
        assert((alpha>0.5 and 1 or 0)==before,'Spanish font base glyph differs')
        image:setPixel(tx+x,ty+y,0,0,0,after)
      end
    end
  end
  ctx.writeImage(image,'fonts/font.png')
end
"""


def extract_font_graphics(en,es,manifest):
    bank,address=manifest['symbols']['Font']
    # _LoadStandardFont: source DE, VRAM $8800, 128 tiles, bank, Get1bpp.
    signature=bytes.fromhex('2100880180')+bytes([bank])
    def locate(rom):
        hits=[]
        for pointer in range(0x4000,0x8000-12):
            start=offset(bank,pointer)
            if rom[start]==0x11 and native_match(rom[start+3:start+9],signature,rom) and rom[start+9] in (0xc3,0xf0):
                source=word(rom,bank,pointer+1)
                offset(bank,source+1023)
                hits.append((pointer,source))
        if len(hits)!=1:raise ValueError('standard font loader must be unique')
        return hits[0]
    ar,a=locate(en);br,b=locate(es)
    if a!=address:raise ValueError('English font source differs from manifest')
    start=offset(bank,b)
    return es[start:start+1024],{'english':key((bank,a)),'spanish':key((bank,b)),
        'english_reference':key((bank,ar)),'spanish_reference':key((bank,br)),'bytes':1024}


def extract_battle_font_graphics(en,es,manifest):
    bank,address=manifest['symbols']['FontBattleExtra']
    # _LoadFontsBattleExtra: DE source, VRAM $9600, 25 2bpp tiles,
    # Get2bpp and the zero-displacement jump to LoadFrame.
    suffix=bytes.fromhex('2100960119')+bytes([bank,0xcd])
    def locate(rom):
        hits=[]
        for pointer in range(0x4000,0x8000-14):
            start=offset(bank,pointer)
            if rom[start]==0x11 and native_match(rom[start+3:start+10],suffix,rom) and native_match(rom[start+12:start+14],bytes.fromhex('1800'),rom):
                source=word(rom,bank,pointer+1)
                offset(bank,source+399)
                hits.append((pointer,source))
        if len(hits)!=1:raise ValueError('battle font loader must be unique')
        return hits[0]
    ar,a=locate(en);br,b=locate(es)
    if a!=address:raise ValueError('English battle font source differs from manifest')
    start=offset(bank,b)
    return es[start:start+400],{'english':key((bank,a)),'spanish':key((bank,b)),
        'english_reference':key((bank,ar)),'spanish_reference':key((bank,br)),'bytes':400}


def battle_font_transform(original,translated):
    if len(original)!=400 or len(translated)!=400:raise ValueError('battle font needs 25 tiles')
    rows=[]
    for tile in range(25):
        for y in range(8):
            pos=tile*16+y*2
            for x in range(8):
                bit=7-x
                old=((original[pos]>>bit)&1)+2*((original[pos+1]>>bit)&1)
                new=((translated[pos]>>bit)&1)+2*((translated[pos+1]>>bit)&1)
                if old!=new:rows.append('  {%d,%d,%d,%d,%d},'%(tile,x,y,old,new))
    return '''-- Original Spanish battle font differences; preserve unchanged tiles.
local changes = {
'''+ '\n'.join(rows)+'''
}
return function(ctx)
  for _,target in ipairs({{'fonts/font_battle_extra.png',128,16,true},
      {'battle/hud/hp_bar.png',96,8,false}}) do
    local image=ctx.readImage(target[1])
    local w,h=image:getDimensions()
    assert(w==target[2] and h==target[3],'Spanish battle font dimensions differ')
    for _,change in ipairs(changes) do
      local tile,x,y,before,after=unpack(change)
      if target[4] or tile<12 then
        x=(tile%(w/8))*8+x;y=math.floor(tile/(w/8))*8+y
        local r,g,b,a=image:getPixel(x,y)
        if target[4] then
          assert((a>0.5 and 1 or 0)==(before>=2 and 1 or 0),'Spanish battle font base ink differs')
          image:setPixel(x,y,0,0,0,after>=2 and 1 or 0)
        else
          local shade=1-before/3
          assert(math.abs(r-shade)<0.01 and math.abs(g-shade)<0.01 and math.abs(b-shade)<0.01 and a>0.99,'Spanish HP base shade differs')
          shade=1-after/3;image:setPixel(x,y,shade,shade,shade,1)
        end
      end
    end
    ctx.writeImage(image,target[1])
  end
end
'''


def extract_pack_graphics(en,es,manifest):
    # Pack_InitGFX: ld hl, source; ld de, vTiles2; ld bc, $60 tiles;
    # ld a, BANK(PackMenuGFX); call FarCopyBytes. The destination, size,
    # source bank and home-bank copy routine are identical in both ROMs.
    bank,address=manifest['symbols']['PackMenuGFX']
    suffix=bytes.fromhex('110090010006')+bytes([0x3e,bank,0xcd])
    def locate(rom):
        hits=[]
        for start in range(offset(bank,0x4000),offset(bank,0x7fff)-13):
            if rom[start]==0x21 and native_match(rom[start+3:start+12],suffix,rom):
                pointer=rom[start+1]+256*rom[start+2]
                offset(bank,pointer+1535)  # enforce entire source in bank
                hits.append((start,pointer))
        if len(hits)!=1:raise ValueError('pack native graphics reference must be unique')
        return hits[0]
    a,old=locate(en);b,new=locate(es)
    if old!=address:raise ValueError('English pack graphics pointer differs')
    tb,ta=manifest['symbols']['DrawPocketName.tilemap']
    start=offset(tb,ta);tilemap=en[start:start+60]
    hits=[];pos=offset(tb,0x4000)
    while True:
        pos=es.find(tilemap,pos,offset(tb,0x7fff)+1)
        if pos<0:break
        hits.append(pos);pos+=1
    if len(hits)!=1:raise ValueError('Spanish pack tilemap must be unique and unchanged')
    def point(pos):return key((pos//0x4000,pos%0x4000+0x4000))
    proof={'menu':{'english':key((bank,old)),'spanish':key((bank,new)),
                   'english_reference':point(a),'spanish_reference':point(b),'bytes':1536},
           'tilemap':{'english':key((tb,ta)),'spanish':point(hits[0]),'bytes':60}}
    start=offset(bank,new)
    return es[start:start+1536],proof


def extract_cancel_label(en,es,english,spanish):
    # ScrollingMenu's cancel branch loads its inline string, calls the
    # home-bank PlaceString and returns. The alternate branch skips the
    # string entirely; its displacement varies with the translated length.
    def locate(rom,charmap):
        bank=9;hits=[]
        for address in range(0x4000,0x8000-14):
            start=offset(bank,address)
            if (native_match(rom[start:start+6],bytes.fromhex('fac8cecb4720'),rom)
                    and rom[start+7]==0x11 and native_match(rom[start+10:start+14],bytes.fromhex('cd740fc9'),rom)):
                pointer=word(rom,bank,address+8)
                if pointer!=address+14:raise ValueError('cancel native pointer differs')
                text,end=name_record(rom,bank,pointer,charmap)
                if address+7+rom[start+6]!=end or not native_match(rom[offset(bank,end):offset(bank,end)+2],bytes.fromhex('545d'),rom):
                    raise ValueError('cancel native branch differs')
                hits.append((text,(bank,pointer)))
        if len(hits)!=1:raise ValueError('cancel native reference must be unique')
        return hits[0]
    (original,a),(translated,b)=locate(en,english),locate(es,spanish)
    if original!='CANCEL':raise ValueError('English cancel label differs')
    label='ScrollingMenu/CANCEL'
    return ([{'label':label,'english':original,'spanish':translated,'original_slots':[],'spanish_slots':[]}],
            {label:{'english':key(a),'spanish':key(b)}})


def extract_option_labels(en,es,english,spanish,expected=('TEXT SPEED','BATTLE SCENE','BATTLE STYLE','SOUND','PRINT','MENU ACCOUNT','FRAME','CANCEL')):
    def locate(rom,charmap):
        hits=[];bank=0x39
        for address in range(0x4000,0x8000-9):
            start=offset(bank,address)
            if native_match(rom[start:start+4],bytes.fromhex('21cac311'),rom) and native_match(rom[start+6:start+9],bytes.fromhex('cd740f'),rom):
                pointer=word(rom,bank,address+4)
                text,_=name_record(rom,bank,pointer,charmap,256)
                parts=text.split('<LF>')
                if len(parts)!=15 or any(part.strip()!=':' for part in parts[1:12:2]) or not parts[13].strip().startswith(':'):
                    raise ValueError('option string layout differs')
                hits.append((parts,(bank,pointer)))
        if len(hits)!=1:raise ValueError('option native placement must be unique')
        return hits[0]
    (a,pa),(b,pb)=locate(en,english),locate(es,spanish)
    if a[::2]!=list(expected) or a[13].strip()!=':TYPE':raise ValueError('English option labels differ')
    records=[];proof={}
    for original,translated in zip(a[::2]+[a[13].strip()],b[::2]+[b[13].strip()]):
        label='Options/'+original
        records.append({'label':label,'english':original,'spanish':translated,'original_slots':[],'spanish_slots':[]})
        proof[label]={'english':key(pa),'spanish':key(pb)}
    return records,proof


def extract_option_values(en,es,english,spanish,specs=None):
    specs=specs or {3:['FAST','MID ','SLOW'],5:['ON ','OFF'],7:['SHIFT','SET  '],9:['MONO  ','STEREO'],11:['LIGHTEST','LIGHTER ','NORMAL  ','DARKER  ','DARKEST '],13:['OFF','ON ']}
    def locate(rom,charmap,row,count):
        bank=0x39;hits=[]
        for col in range(20):
            coord=0xc3a0+row*20+col
            sig=bytes([0x21,coord&255,coord>>8])+bytes.fromhex('cd740fa7c9')
            start=offset(bank,0x4000)
            while True:
                start=rom.find(native_bytes(rom,sig),start,offset(bank,0x7fff)+1)
                if start<0:break
                hits.append((start,col));start+=1
        if len(hits)!=1:raise ValueError('option value display must be unique')
        start,col=hits[0];address=start%0x4000+0x4000
        if row in (3,11):
            if not native_match(rom[start-10:start-7],bytes.fromhex('060021'),rom) or not native_match(rom[start-5:start],bytes.fromhex('09095e2356'),rom):
                raise ValueError('text speed native table lookup differs')
            table=word(rom,bank,address-7)
            pointers=[word(rom,bank,table+2*i) for i in range(count)]
            if pointers[0]!=table+2*count:raise ValueError('text speed table boundary differs')
        else:
            if rom[start-3]!=0x11:raise ValueError('option second choice pointer differs')
            second=word(rom,bank,address-2);first=address+8
            load=bytes([0x11,first&255,first>>8,0x18])
            refs=[p for p in range(start-32,start-4) if rom[p:p+4]==load]
            if len(refs)!=1 or refs[0]+5+rom[refs[0]+4]!=start:
                raise ValueError('option first choice branch differs')
            pointers=[first,second]
        records=[]
        for i,pointer in enumerate(pointers):
            text,end=name_record(rom,bank,pointer,charmap)
            if i+1<len(pointers) and end!=pointers[i+1]:raise ValueError('option value strings are not contiguous')
            records.append((text,(bank,pointer)))
        return records,col
    records=[];proof={}
    for row,expected in sorted(specs.items()):
        old,old_col=locate(en,english,row,len(expected));new,new_col=locate(es,spanish,row,len(expected))
        if [v[0] for v in old]!=expected:raise ValueError('English option values differ')
        for (original,a),(translated,b) in zip(old,new):
            label=f'OptionValues/row{row}/'+original
            records.append({'label':label,'english':original,'spanish':translated,'original_slots':[],'spanish_slots':[]})
            proof[label]={'english':key(a),'spanish':key(b),'english_column':old_col,'spanish_column':new_col,'row':row}
    return records,proof


def extract_start_menu(en,es,english,spanish,expected=None):
    expected=expected or [('POKéDEX','POKéMON\ndatabase'),('POKéMON','Party <PK><MN>\nstatus'),
        ('PACK','Contains\nitems'),('<PLAYER>','Your own\nstatus'),('SAVE','Save your\nprogress'),
        ('OPTION','Change\nsettings'),('EXIT','Close this\nmenu'),('<PO><KE>GEAR',"Trainer's\nkey device"),('QUIT','Quit and\nbe judged.')]
    ids=['pokedex','pokemon','pack','status','save','option','exit','pokegear','quitContest']
    def locate(rom,charmap):
        bank=4;hits=[]
        for address in range(0x4000,0x8000-62):
            start=offset(bank,address)
            header='a8003ed0' if rom[0x134:0x13e]==b'PM_CRYSTAL' else 'a80029cf'
            if rom[start:start+4]==bytes.fromhex(header) and word(rom,bank,address+6)==address+8:
                hits.append(address)
        if len(hits)!=1:raise ValueError('start menu data must be unique')
        address=hits[0];table=address+8;entries=[];handlers=[]
        name_end=table+54
        for i in range(9):
            handler=word(rom,bank,table+i*6)
            name=word(rom,bank,table+i*6+2);desc=word(rom,bank,table+i*6+4)
            offset(bank,handler)
            if name!=name_end:raise ValueError('start menu label boundary differs')
            label,name_end=name_record(rom,bank,name,charmap)
            text,_=name_record(rom,bank,desc,charmap,64)
            text=text.replace('<NEXT>','\n').replace('<LINE>','\n')
            entries.append(((label,(bank,name)),(text,(bank,desc))))
            handlers.append(handler)
        return entries,[p-handlers[0] for p in handlers]
    old,old_handlers=locate(en,english);new,new_handlers=locate(es,spanish)
    if old_handlers!=new_handlers:raise ValueError('start menu handler order differs')
    records=[];proof={}
    for i,(a,b) in enumerate(zip(old,new)):
        for j,field in enumerate(['name','description']):
            original,pa=a[j];translated,pb=b[j]
            if original!=expected[i][j]:raise ValueError('English start menu text differs')
            if original=='<PLAYER>':
                if translated!=original:raise ValueError('start menu player marker differs')
                continue
            label='StartMenu/'+ids[i]+'/'+field
            record={'label':label,'english':original,'spanish':translated,'original_slots':[],'spanish_slots':[]}
            if i==8 and field=='name':record['context']='start_menu.quitContest'
            records.append(record);proof[label]={'english':key(pa),'spanish':key(pb)}
    return records,proof


def extract_certificate_graphics(en,es,manifest,engine,english,spanish):
    def loader(label,suffix):
        bank,expected=manifest['symbols'][label]
        def locate(rom):
            hits=[]
            banks=range(1,len(rom)//0x4000) if label=='DiplomaGFX' else [bank]
            for candidate_bank in banks:
                for address in range(0x4000,0x7fe0):
                    p=offset(candidate_bank,address)
                    if rom[p]!=0x21 or not native_match(rom[p+3:p+3+len(suffix)],suffix,rom):continue
                    if label=='DiplomaGFX' and not native_match(rom[p+12:p+19],bytes.fromhex('11a0c3016801cd'),rom):continue
                    hits.append((candidate_bank,word(rom,candidate_bank,address+1),address))
            if len(hits)!=1:raise ValueError('native certificate loader must be unique: '+label)
            return hits[0]
        old,new=locate(en),locate(es)
        if old[:2]!=(bank,expected):raise ValueError('certificate English symbol differs: '+label)
        return old,new
    old,new=loader('CardStatusGFX',bytes.fromhex('1190920160053e09cd'))
    status=es[offset(*new[:2]):offset(*new[:2])+96]
    proof={'status':{'english':key(old[:2]),'spanish':key(new[:2])}}
    old,new=loader('DiplomaGFX',bytes.fromhex('110090cd000b21'))
    a=decompress_lz3(en[offset(*old[:2]):],engine)
    raw=decompress_lz3(es[offset(*new[:2]):],engine)
    if len(raw)!=112*16 or len(a)!=len(raw):raise ValueError('native diploma tile count differs')
    old_map=word(en,old[0],old[2]+10);new_map=word(es,new[0],new[2]+10)
    original=en[offset(old[0],old_map):offset(old[0],old_map)+360]
    translated=es[offset(new[0],new_map):offset(new[0],new_map)+360]
    proof['diploma']={'english':key(old[:2]),'spanish':key(new[:2]),'same_tilemap':original==translated}
    proof['diploma_tiles']=112
    labels,label_proof=extract_native_print_labels(en,es,english,spanish,[
        ('NAME/<NEXT><NEXT>MONEY',9,'21cac311','cd740f21f2c311')],prefix='TrainerCard')
    name,money=labels[0]['spanish'].split('<NEXT><NEXT>')
    proof.update(label_proof)
    return {'trainer_card/status.png':tile_png(status,48,8),'diploma/diploma.png':tile_png(raw,128,56)}, {'trainerCard':{'name':name,'money':money},'diplomaMap':list(translated)},proof


def extract_seer_names(en,es,english,spanish):
    bank=0x13
    def locate(rom,charmap):
        times=[];unknown=[]
        prefix=bytes.fromhex('fa3bd0e6c0281307073d21')
        suffix=bytes.fromhex('cd1134545d21')
        for address in range(0x4000,0x7fe0):
            p=offset(bank,address);mid=p+len(prefix)
            if native_match(rom[p:mid],prefix,rom) and native_match(rom[mid+2:mid+2+len(suffix)],suffix,rom):
                pointer=word(rom,bank,address+len(prefix));rows=[]
                for _ in range(3):
                    at=pointer;text,pointer=name_record(rom,bank,pointer,charmap)
                    rows.append((text,(bank,at)))
                times.append(rows)
            if (rom[p]==0x21 and rom[p+3:p+7]==bytes.fromhex('010b00cd') and rom[p+9]==0xc9
                    and word(rom,bank,address+1)==address+10):
                text,_=name_record(rom,bank,address+10,charmap)
                unknown.append((text,(bank,address+10)))
        if len(times)!=1 or len(unknown)!=1:raise ValueError('Seer name loaders must be unique')
        return times[0]+unknown
    old,new=locate(en,english),locate(es,spanish);records=[];proof={}
    if [row[0] for row in old]!=['Morning','Day','Night','Unknown']:raise ValueError('English Seer names differ')
    for (source,a),(target,b) in zip(old,new):
        label='SeerNames/'+source
        records.append({'label':label,'english':source,'spanish':target,'original_slots':[],'spanish_slots':[]})
        proof[label]={'english':key(a),'spanish':key(b)}
    return records,proof


def bind_native_port_fallbacks(strings,sources,records):
    by_label={row['label']:row for row in records};proof={}
    specs={
        'You have no room\nfor it.':'_HaveNoRoomText',
        'Have you met KURT?\nHis custom #\vBALLS should help.':'_OakRating12',
        'Start!':'_SlotsStartText',
        '{PLAYER} found\n{STRBUF}!':'_FoundItemText',
        '{PLAYER} found\n{STRBUF}.':'_FoundItemText',
        "But {PLAYER} can't\ncarry any more\vitems!":'_CantCarryItemText',
    }
    for source,label in specs.items():
        if source in sources and source not in strings and label in by_label:
            strings[source]=terminal(by_label[label]['spanish'])
            proof[source]={'labels':[label],'match':'native text bound to shared port fallback'}
    source='Go! %s!'
    if source in sources and source not in strings:
        a,b=by_label['_GoMonText'],by_label['_BattleMonNicknameText']
        if a['english']!='Go! ' or terminal(b['english'])!='{STRBUF}!':raise ValueError('native send-out assembly differs')
        strings[source]=terminal(a['spanish'])+terminal(b['spanish']).replace('{STRBUF}','%s')
        proof[source]={'labels':['_GoMonText','_BattleMonNicknameText'],'match':'native send-out assembly'}
    if 'Congratulations!' in sources and 'Congratulations!' not in strings:
        strings['Congratulations!']=by_label['_CongratulationsYourPokemonText']['spanish'].split('\n')[0]
        proof['Congratulations!']={'labels':['_CongratulationsYourPokemonText'],'match':'original congratulations line'}
    return proof


def reviewed_ui_bindings(strings,sources,records):
    """Port UI labels reviewed against native contexts; port messages are explicit."""
    values={
        'SPECIAL':'ESPECIAL','DEPOSIT':'DEJAR','WITHDRAW':'SACAR',
        'FIGHT':'LUCHA','RUN':'ESC','STATS':'ESTAD.',
        "You can't deposit\nthe last POKéMON!":'¡No puedes dejar\ntu último POKéMON!',
        'PLAYER':'JUGADOR','that you have':'que has',
        'BUY':'COMPRAR','SELL':'VENDER','PP':'PP','NAME':'NOMBRE','NEW NAME':'NUEVO N.',
        'ITEMS':'OBJETOS','ITEM':'OBJETO','SWITCH':'CAMBIO','OWN':'TIEN','SEEN':'VIST',
        "Printed %s's\ndata!\f":'¡Datos de %s\nimpresos!\f',
        'Printer error!\n%s':'Error al imprimir:\n%s',
        'kg':'kg','lb':'lb','m':'m','FLY':'VUELO',
        "You don't have\nenough money.":'No tienes\nsuficiente dinero.',
        'None':'Ninguno','MONEY':'DINERO','PLAY TIME':'TIEMPO J.',
        'BATTLE':'COMBATE','TRADE':'CAMBIO','now!':'¡Ahora!',
    }
    aliases={'FIGHT':'battle.actions|FIGHT','RUN':'battle.actions|RUN',
             'STATS':'storage.actions|STATS','SWITCH':'party.actions|SWITCH',
             'OWN':'pokedex.list|OWN','SEEN':'pokedex.list|SEEN','None':'contest.caught|None'}
    proof={}
    for source,target in values.items():
        if source not in sources or source in strings:continue
        context=aliases.get(source)
        if context in strings:target=strings[context]
        strings[source]=target
        proof[source]={'engine':sources[source],
            'match':'reviewed port UI label; original context alias' if context else 'reviewed shared UI wording',
            'context':context}
    return proof


def extract_crystal_title_and_summary_labels(en,es,english,spanish):
    """Pair Crystal's own menu structures, including its wider Spanish panel."""
    def title(rom,charmap):
        hits=[];bank=0x12
        for address in range(0x4000,0x7fc0):
            p=offset(bank,address)
            if rom[p:p+5]!=bytes.fromhex('4000000710'):continue
            if word(rom,bank,address+5)!=address+8 or rom[p+7:p+10]!=bytes.fromhex('018000'):continue
            pointer=word(rom,bank,address+14)
            if pointer!=address+16:continue
            rows=[]
            for _ in range(6):
                at=pointer;text,pointer=name_record(rom,bank,pointer,charmap,64)
                rows.append((text,(bank,at)))
            hits.append(rows)
        if len(hits)!=1:raise ValueError('Crystal title menu structure must be unique')
        return hits[0]
    old,new=title(en,english),title(es,spanish)
    expected=['CONTINUE','NEW GAME','OPTION','MYSTERY GIFT','MOBILE','MOBILE STUDIUM']
    if [r[0] for r in old]!=expected:raise ValueError('English Crystal title menu differs')
    records=[];proof={}
    def append(label,source,target,a,b):
        slots=[('named','PLAYER')] if '{PLAYER}' in source else []
        records.append({'label':label,'english':source,'spanish':target,
                        'original_slots':slots,'spanish_slots':slots})
        proof[label]={'english_point':key(a),'spanish_point':key(b),'native_spanish':target}
    for index,((source,a),(target,b)) in enumerate(zip(old,new)):
        append('MainMenu/'+str(index),source,target,a,b)
    def summary(rom,charmap):
        hits=[];bank=1
        prefix=bytes.fromhex('4000000911' if rom[0x142]==ord('S') else '400000090f')
        for address in range(0x4000,0x7fc0):
            p=offset(bank,address)
            if rom[p:p+5]!=prefix or word(rom,bank,address+5)!=address+8:continue
            if rom[p+7:p+10]!=bytes.fromhex('010004'):continue
            pointer=address+10;rows=[]
            for _ in range(4):
                at=pointer;text,pointer=decode(rom,bank,pointer,charmap)
                rows.append((text,(bank,at)))
            hits.append(rows)
        if len(hits)!=2:raise ValueError('Crystal player summary panels must be unique pair')
        return hits
    old,new=summary(en,english),summary(es,spanish)
    expected=[['PLAYER','BADGES','POKéDEX','TIME'],['PLAYER {PLAYER}','BADGES',' ','TIME']]
    seen={}
    for index,(source,target) in enumerate(zip(old,new)):
        if [row[0] for row in source]!=expected[index]:raise ValueError('English Crystal summary panel differs')
        for (name,a),(translated,b) in zip(source,target):
            if name==' ':continue
            # The original Spanish layout prints the name in its own field.
            if '{PLAYER}' in name:translated+=' {PLAYER}'
            if name in seen:
                if seen[name]!=translated:raise ValueError('Crystal summary panels disagree')
                continue
            seen[name]=translated
            append('PlayerSummary/'+name,name,translated,a,b)
    return records,proof


def extract_title_and_summary_labels(en,es,english,spanish):
    """Pair native title options and player-summary labels."""
    if en[0x134:0x13e]==b'PM_CRYSTAL':
        return extract_crystal_title_and_summary_labels(en,es,english,spanish)
    # The ROM stores these small labels as contiguous text records in bank 1.
    # The paired points are verified by content, including the two repeated
    # summary panels; no address-neighbour fallback is used.
    rows=[
        ('MainMenu/continue', (1,0x5aa7), (1,0x5aa5), 'CONTINUE', 'CONTINUAR'),
        ('MainMenu/new_game', (1,0x5ab0), (1,0x5aaf), 'NEW GAME', 'JUEGO NUEVO'),
        ('MainMenu/option', (1,0x5ab9), (1,0x5abb), 'OPTION', 'OPCIÓN'),
    ]
    summary=[
        ('PLAYER {PLAYER}', 'JUGADOR', [(1,0x5efb),(1,0x5f1f)], [(1,0x5f26),(1,0x5f50)]),
        ('BADGES', 'MEDALLAS', [(1,0x5f04),(1,0x5f28)], [(1,0x5f2e),(1,0x5f58)]),
        ('TIME', 'TIEMPO J.', [(1,0x5f10),(1,0x5f31)], [(1,0x5f3c),(1,0x5f63)]),
    ]
    records=[];proof={}
    def native(rom,point,charmap):
        return decode(rom,*point,charmap)[0]
    for label,a,b,old,new in rows:
        got_old=native(en,a,english);got_new=native(es,b,spanish)
        if (got_old,got_new)!=(old,new):
            raise ValueError('verified title menu text differs: '+label)
        records.append({'label':label,'english':old,'spanish':new,
            'original_slots':[],'spanish_slots':[]})
        proof[label]={'english_point':key(a),'spanish_point':key(b),
            'native_english':got_old,'native_spanish':got_new}
    for old,new,old_points,new_points in summary:
        old_values=[native(en,p,english) for p in old_points]
        new_values=[native(es,p,spanish) for p in new_points]
        expected_old=old
        expected_new=new
        if any(value!=expected_old for value in old_values) or any(value!=expected_new for value in new_values):
            raise ValueError('verified player summary text differs: '+old)
        slots=[('named','PLAYER')] if '{PLAYER}' in old else []
        translated=new+' {PLAYER}' if slots else new
        records.append({'label':'PlayerSummary/'+old,'english':old,
            'spanish':translated,'original_slots':slots,'spanish_slots':slots})
        proof['PlayerSummary/'+old]={'english_points':[key(p) for p in old_points],
            'spanish_points':[key(p) for p in new_points],
            'native_english':old_values,'native_spanish':new_values,
            'runtime_source':'PLAYER %s' if slots else old,
            'runtime_translation':new+' %s' if slots else new}
    return records,proof


def extract_contest_status(en,es,english,spanish):
    def locate(rom,charmap):
        bank=9;refs={}
        for row in (1,5,3):
            coord=0xc3a0+row*20+1;prefix=bytes([0x21,coord&255,coord>>8,0x11])
            hits=[]
            for address in range(0x4000,0x8000-9):
                start=offset(bank,address)
                if native_match(rom[start:start+4],prefix,rom) and native_match(rom[start+6:start+9],bytes.fromhex('cd740f'),rom):
                    hits.append((address,word(rom,bank,address+4)))
            refs[row]=hits
        candidates=[]
        for caught_at,caught in refs[1]:
            records=[];pointer=caught
            try:
                for _ in range(4):
                    old=pointer;text,pointer=name_record(rom,bank,pointer,charmap)
                    records.append((text,(bank,old)))
            except ValueError:continue
            balls=records[1][1][1];none=records[2][1][1];level=records[3][1][1]
            nearby_balls=[at for at,p in refs[5] if p==balls and abs(at-caught_at)<128]
            nearby_level=[at for at,p in refs[3] if p==level and abs(at-caught_at)<128]
            if len(nearby_balls)!=1 or len(nearby_level)!=1:continue
            needle=bytes.fromhex('fae7dca711')+bytes([none&255,none>>8,0x28])
            start=offset(bank,min(caught_at,nearby_balls[0],nearby_level[0]))
            end=offset(bank,max(caught_at,nearby_balls[0],nearby_level[0])+9)
            if sum(native_match(rom[pos:pos+len(needle)],needle,rom) for pos in range(start,end-len(needle)+1))!=1:continue
            candidates.append(records)
        if len(candidates)!=1:raise ValueError('contest status pointer group must be unique')
        return candidates[0]
    old,new=locate(en,english),locate(es,spanish)
    records=[];proof={}
    for expected,(original,a),(translated,b) in zip(['CAUGHT','BALLS:','None','LEVEL'],old,new):
        if original!=expected:raise ValueError('English contest status differs')
        label='ContestStatus/'+original
        record={'label':label,'english':original,'spanish':translated,'original_slots':[],'spanish_slots':[]}
        if original=='None':record['context']='contest.caught'
        records.append(record);proof[label]={'english':key(a),'spanish':key(b)}
    return records,proof


def extract_party_actions(en,es,english,spanish):
    expected=['STATS','SWITCH','ITEM','CANCEL','MOVE','MAIL','ERROR!']
    def locate(rom,charmap):
        bank=9;hits=[]
        nth=bytes.fromhex('a7c8c5470e502ab920fc0520f9c1c9')
        for address in range(0x4000,0x8000-12):
            start=offset(bank,address)
            if (native_match(rom[start:start+4],bytes.fromhex('237e3d21'),rom) and rom[start+6]==0xcd
                    and native_match(rom[start+9:start+12],bytes.fromhex('545dc9'),rom)):
                callee=word(rom,bank,address+7)
                if callee>=0x4000 or not native_match(rom[callee:callee+len(nth)],nth,rom):continue
                pointer=word(rom,bank,address+4);values=[]
                for _ in expected:
                    old=pointer;text,pointer=name_record(rom,bank,pointer,charmap)
                    values.append((text,(bank,old)))
                hits.append(values)
        if len(hits)!=1:raise ValueError('party action string loader must be unique')
        return hits[0]
    old,new=locate(en,english),locate(es,spanish)
    records=[];proof={}
    for expected_name,(original,a),(translated,b) in zip(expected,old,new):
        if original!=expected_name:raise ValueError('English party action differs')
        label='PartyActions/'+original
        records.append({'label':label,'english':original,'spanish':translated,'context':'party.actions','original_slots':[],'spanish_slots':[]})
        proof[label]={'english':key(a),'spanish':key(b)}
    return records,proof


def extract_party_compatibility(en,es,english,spanish):
    # PlaceAbleNotAble: test C, return one of two inline string pointers.
    def locate(rom,charmap):
        bank=20;hits=[]
        for address in range(0x4000,0x8000-12):
            start=offset(bank,address)
            if (native_match(rom[start:start+5],bytes.fromhex('79a7200411'),rom) and
                    native_match(rom[start+7:start+9],bytes.fromhex('c911'),rom) and rom[start+11]==0xc9):
                no=word(rom,bank,address+5);yes=word(rom,bank,address+9)
                if yes!=address+12:continue
                able,end=name_record(rom,bank,yes,charmap)
                if no!=end:continue
                unable,_=name_record(rom,bank,no,charmap)
                hits.append([(able,(bank,yes)),(unable,(bank,no))])
        if len(hits)!=1:raise ValueError('party compatibility selector must be unique')
        return hits[0]
    old,new=locate(en,english),locate(es,spanish)
    records=[];proof={}
    for expected,(original,a),(translated,b) in zip(['ABLE','NOT ABLE'],old,new):
        if original!=expected:raise ValueError('English party compatibility differs')
        label='PartyCompatibility/'+original
        records.append({'label':label,'english':original,'spanish':translated,'original_slots':[],'spanish_slots':[]})
        proof[label]={'english':key(a),'spanish':key(b)}
    return records,proof


def extract_fainted_label(en,es,english,spanish):
    # PlaceStatusString's zero-HP arm calls CopyStatusString with its inline label.
    def locate(rom,charmap):
        bank=20;hits=[]
        for address in range(0x4000,0x8000-12):
            start=offset(bank,address)
            if (native_match(rom[start:start+2],bytes.fromhex('d511'),rom) and rom[start+4]==0xcd and
                    native_match(rom[start+7:start+12],bytes.fromhex('d13e01a7c9'),rom)):
                pointer=word(rom,bank,address+2);callee=word(rom,bank,address+5)
                if pointer!=address+12:continue
                value,end=name_record(rom,bank,pointer,charmap)
                if callee!=end:continue
                target=offset(bank,callee)
                if not native_match(rom[target:target+9],bytes.fromhex('1a13221a13221a77c9'),rom):continue
                hits.append((value,(bank,pointer)))
        if len(hits)!=1:raise ValueError('fainted status loader must be unique')
        return hits[0]
    (original,a),(translated,b)=locate(en,english),locate(es,spanish)
    if original!='FNT':raise ValueError('English fainted status differs')
    label='PartyStatus/FNT'
    return [{'label':label,'english':original,'spanish':translated,'original_slots':[],'spanish_slots':[]}],{label:{'english':key(a),'spanish':key(b)}}


def extract_status_labels(en,es,english,spanish):
    # PlaceNonFaintStatus checks poison, burn, freeze, paralysis, then sleep.
    template=bytes.fromhex('d51a110000cb5f201c110000cb672015110000cb6f200e110000cb772007110000e6072806cd00003e01a7d1c9')
    pointer_positions=[3,10,17,24,31,38]
    masked={p+d for p in pointer_positions for d in (0,1)}
    def locate(rom,charmap):
        bank=20;hits=[]
        for address in range(0x4009,0x8000-len(template)):
            start=offset(bank,address);raw=rom[start:start+len(template)]
            if any(raw[i]!=v for i,v in enumerate(template) if i not in masked):continue
            if word(rom,bank,address+38)!=address-9:continue
            if not native_match(rom[start-9:start],bytes.fromhex('1a13221a13221a77c9'),rom):continue
            cursor=address+len(template);values=[];points=[]
            for _ in range(5):
                points.append(cursor);value,end=name_record(rom,bank,cursor,charmap)
                values.append((value,(bank,cursor)));cursor=end
            if [word(rom,bank,address+p) for p in pointer_positions[:5]]!=[points[i] for i in [1,2,3,4,0]]:continue
            hits.append(values)
        if len(hits)!=1:raise ValueError('nonfaint status selector must be unique')
        return hits[0]
    old,new=locate(en,english),locate(es,spanish)
    records=[];proof={}
    for expected,(original,a),(translated,b) in zip(['SLP','PSN','BRN','FRZ','PAR'],old,new):
        if original!=expected:raise ValueError('English status label differs')
        label='StatusLabels/'+original
        records.append({'label':label,'english':original,'spanish':translated,'original_slots':[],'spanish_slots':[]})
        proof[label]={'english':key(a),'spanish':key(b)}
    return records,proof


def extract_summary_headings(en,es,english,spanish):
    expected=['STATUS/<NEXT>TYPE/','OK ','EXP POINTS','LEVEL UP','TO','POKéRUS']
    tail=bytes.fromhex('21a7c301140016123e3177091520f9c9')
    def locate(rom,charmap):
        crystal=rom[0x134:0x13e]==b'PM_CRYSTAL'
        bank=19 if crystal else 20;hits=[]
        for address in range(0x4000,0x8000-9):
            start=offset(bank,address)
            if crystal:
                if rom[start]!=0x11 or not native_match(rom[start+3:start+9],bytes.fromhex('2190c4cd740f'),rom):continue
                table=word(rom,bank,address+1)
            else:
                if not native_match(rom[start:start+4],bytes.fromhex('2190c411'),rom) or not native_match(rom[start+6:start+9],bytes.fromhex('cd740f'),rom):continue
                table=word(rom,bank,address+4)
            if table<=address:continue
            cursor=table;values=[]
            try:
                for _ in expected:
                    pointer=cursor;value,cursor=name_record(rom,bank,cursor,charmap)
                    values.append((value,(bank,pointer)))
            except ValueError:continue
            end=offset(bank,cursor)
            if not crystal and not native_match(rom[end:end+len(tail)],tail,rom):continue
            # Every entry is used by a native PlaceString call in this page.
            native=rom[start:offset(bank,table)]
            valid=True
            for _,(_,pointer) in values:
                ref=bytes([0x11,pointer&255,pointer>>8]);pos=native.find(ref)
                if pos<0 or (native_bytes(rom,bytes.fromhex('cd740f')) if crystal else bytes.fromhex('740f')) not in native[pos+3:pos+11]:valid=False
            if valid:hits.append(values)
        if len(hits)!=1:raise ValueError('summary heading table must be unique')
        return hits[0]
    old,new=locate(en,english),locate(es,spanish)
    records=[];proof={}
    for source,(original,a),(translated,b) in zip(expected,old,new):
        if original!=source:raise ValueError('English summary heading differs')
        pairs=list(zip(original.split('<NEXT>'),translated.split('<NEXT>')))
        if len(pairs)!=len(original.split('<NEXT>')) or len(pairs)!=len(translated.split('<NEXT>')):raise ValueError('summary heading line structure differs')
        for source,value in pairs:
            source=source.rstrip();value=value.rstrip()
            label='SummaryHeadings/'+source
            records.append({'label':label,'english':source,'spanish':value,'original_slots':[],'spanish_slots':[]})
            proof[label]={'english':key(a),'spanish':key(b)}
    return records,proof


def extract_storage_actions(en,es,english,spanish):
    expected=[['DEPOSIT','STATS','RELEASE','CANCEL'],['WITHDRAW','STATS','RELEASE','CANCEL'],
        ['MOVE','STATS','CANCEL'],['SWITCH','NAME','PRINT','QUIT']]
    def locate(rom,charmap):
        groups=[]
        for address in range(0x4000,0x8000-10):
            pos=offset(56,address);raw=rom[pos:pos+10]
            if not native_match(raw[:2],bytes.fromhex('4004'),rom) or not native_match(raw[3:5],bytes.fromhex('0d13'),rom) or not native_match(raw[7:9],bytes.fromhex('0180'),rom) or raw[9] not in (3,4):continue
            if word(rom,56,address+5)!=address+8:continue
            cursor=address+10;values=[]
            for _ in range(raw[9]):
                pointer=cursor;value,cursor=name_record(rom,56,cursor,charmap)
                values.append((value,(56,pointer)))
            groups.append(values)
        if len(groups)!=4:raise ValueError('storage submenus must form native four-header group')
        return groups
    old,new=locate(en,english),locate(es,spanish);records=[];proof={}
    for mode,source,a,b in zip(['deposit','withdraw','move','box'],expected,old,new):
        if [v for v,_ in a]!=source or len(a)!=len(b):raise ValueError('English storage action identity differs')
        if mode=='box':continue
        for index,((original,pa),(translated,pb)) in enumerate(zip(a,b)):
            label='StorageActions/'+mode+'/'+str(index)
            records.append({'label':label,'english':original,'spanish':translated,'context':'storage.actions','original_slots':[],'spanish_slots':[]})
            proof[label]={'english':key(pa),'spanish':key(pb)}
    return records,proof


def extract_storage_captions(en,es,english,spanish):
    expected=['Choose a <PK><MN>.',"What's up?",'Release <PK><MN>?','Move to where?',"It's your last <PK><MN>!",
        "There's no room!",'No more usable <PK><MN>!','Remove MAIL.','Released <PK><MN>.','Bye,','Stored ','Got ','Non.','The BOX is full.',"The party's full!",'No releasing EGGS!']
    def locate(rom,charmap):
        pointers=Counter()
        for address in range(0x4000,0x8000-11):
            pos=offset(56,address);raw=rom[pos:pos+11]
            if raw[0]==0x11 and raw[3]==0xcd and native_match(raw[6:11],bytes.fromhex('3e05ea2dca'),rom):
                pointers[raw[1]+256*raw[2]]+=1
        pointers=[pointer for pointer,count in pointers.items() if count==3]
        if len(pointers)!=1:raise ValueError('storage prompt reference must be unique')
        cursor=pointers.pop();values=[]
        for _ in expected:
            pointer=cursor;value,cursor=name_record(rom,56,cursor,charmap,64)
            values.append((value,(56,pointer)))
        return values
    old,new=locate(en,english),locate(es,spanish)
    records=[];proof={}
    for index,(source,(original,a),(translated,b)) in enumerate(zip(expected,old,new)):
        if original!=source:raise ValueError('English storage caption differs')
        label='StorageCaptions/'+str(index)
        proof[label]={'english':key(a),'spanish':key(b)}
        if index in (9,10,11,12):continue
        records.append({'label':label,'english':source,'spanish':translated,'original_slots':[],'spanish_slots':[]})
    def suffix(rom,point,charmap,bye=False):
        pointer=point[1];prefix=bytes([17,pointer&255,pointer>>8])+bytes.fromhex('cd740f6960')
        hits=[]
        for address in range(0x4000,0x8000-28):
            pos=offset(56,address)
            if not native_match(rom[pos:pos+len(prefix)],prefix,rom):continue
            cursor=pos+len(prefix);gap=''
            if bye and rom[cursor]==0x23:gap=' ';cursor+=1
            tail=bytes.fromhex('116bcfcd740f696036' if bye else '116bcfcd740f3e')
            if not native_match(rom[cursor:cursor+len(tail)],tail,rom):continue
            code=rom[cursor+len(tail)]
            if code not in charmap:raise ValueError('unknown storage suffix glyph')
            hits.append((gap,charmap[code],key((56,address))))
        if len(hits)!=1:raise ValueError('storage nickname append reference must be unique')
        return hits[0]
    for index,source in [(10,'Stored %s!'),(11,'Got %s!')]:
        _,original,pa=suffix(en,old[index][1],english)
        _,translated,pb=suffix(es,new[index][1],spanish)
        if original!='!':raise ValueError('English storage suffix differs')
        label='StorageCaptions/'+str(index)
        records.append({'label':label,'english':source,'spanish':new[index][0]+'%s'+translated,'original_slots':[],'spanish_slots':[]})
        proof[label]['append']={'english':pa,'spanish':pb,'spanish_suffix':translated}
    gap,original,pa=suffix(en,old[9][1],english,True)
    translated_gap,translated,pb=suffix(es,new[9][1],spanish,True)
    if gap!=' ' or original!='!':raise ValueError('English release append differs')
    records.append({'label':'StorageCaptions/released','english':'Released <PK><MN>.\fBye,\n%s!',
        'spanish':new[8][0]+'\f'+new[9][0]+translated_gap+'%s'+translated,'original_slots':[],'spanish_slots':[]})
    proof['StorageCaptions/released']={'parts':['StorageCaptions/8','StorageCaptions/9'],
        'append':{'english':pa,'spanish':pb,'spanish_gap':translated_gap,'spanish_suffix':translated}}
    return records,proof


def extract_pc_menu_labels(en,es,english,spanish):
    groups=[(3,'4000001113','8000',['WITHDRAW <PK><MN>','DEPOSIT <PK><MN>','CHANGE BOX','MOVE <PK><MN> W/O MAIL','SEE YA!']),
        (5,'4800000c0f','a000',["<PLAYER>'s PC","BILL's PC","PROF.OAK's PC",'HALL OF FAME','TURN OFF']),
        (5,'4000000c0f','a000',['WITHDRAW ITEM','DEPOSIT ITEM','TOSS ITEM','MAIL BOX','DECORATION','TURN OFF','LOG OFF'])]
    records=[];proof={}
    for bank,header,flags,expected in groups:
        def locate(rom,charmap):
            hits=[]
            for address in range(0x4000,0x8000-16):
                start=offset(bank,address);raw=rom[start:start+16]
                if raw[:4]!=bytes.fromhex(header)[:4] or not native_match(raw[7:10],bytes.fromhex('01'+flags),rom):continue
                if raw[4] not in ([14,15] if len(expected)==7 else [bytes.fromhex(header)[4]]):continue
                if word(rom,bank,address+5)!=address+8:continue
                table=word(rom,bank,address+14)
                if table!=address+16:continue
                cursor=table+(4*len(expected) if bank==5 else 0);values=[];valid=True
                for index in range(len(expected)):
                    pointer_index=([0,1,2,3,4,6,5][index] if len(expected)==7 else index)
                    if bank==5 and word(rom,bank,table+pointer_index*4+2)!=cursor:valid=False;break
                    pointer=cursor;value,cursor=name_record(rom,bank,cursor,charmap,64)
                    values.append((value,(bank,pointer)))
                if not valid:continue
                items=word(rom,bank,address+10)
                if bank==3:
                    if items!=cursor+10 or not native_match(rom[offset(bank,items):offset(bank,items)+7],bytes.fromhex('050001020304ff'),rom):continue
                else:
                    tail=bytes.fromhex('050001020305ff06000102030406ff' if len(expected)==7 else '03010004ff0401000204ff050100020304ff')
                    if items!=cursor or not native_match(rom[offset(bank,items):offset(bank,items)+len(tail)],tail,rom):continue
                hits.append(values)
            if len(hits)!=1:raise ValueError('PC menu table must be unique')
            return hits[0]
        for source,(original,a),(translated,b) in zip(expected,locate(en,english),locate(es,spanish)):
            if original!=source:raise ValueError('English PC menu identity differs')
            if '<PLAYER>' in original:
                if translated.count('<PLAYER>')!=1:raise ValueError('PC player-name placeholder differs')
                original=original.replace('<PLAYER>','%s');translated=translated.replace('<PLAYER>','%s')
            label=('PlayerPCMenus/' if len(expected)==7 else 'PCMenus/')+source
            records.append({'label':label,'english':original,'spanish':translated,'original_slots':[],'spanish_slots':[]})
            proof[label]={'english':key(a),'spanish':key(b)}
    return records,proof


def extract_intro_names(en,es,english,spanish,edition='gold'):
    def locate(rom,charmap):
        crystal=edition=='crystal';bank=0x22 if crystal else 1
        header_size=11 if crystal else 10
        hits=[]
        for address in range(0x4000,0x8000-10):
            start=offset(bank,address);raw=rom[start:start+header_size]
            if not native_match(raw[:5],bytes.fromhex('4000000b0a'),rom):continue
            if raw[7:]!=(bytes.fromhex('01009105') if crystal else bytes.fromhex('019105')):continue
            if word(rom,bank,address+5)!=address+(9 if crystal else 8):continue
            cursor=address+header_size;items=[];points=[]
            for _ in range(5):
                points.append(key((bank,cursor)));value,cursor=name_record(rom,bank,cursor,charmap)
                items.append(value)
            indent=byte(rom,bank,cursor);title_point=cursor+1
            title,_=name_record(rom,bank,title_point,charmap)
            hits.append(({'items':items,'title':title,'titleX':indent},
                {'menu':key((bank,address)),'items':points,'title':key((bank,title_point))}))
        if len(hits)!=(2 if crystal else 1):raise ValueError('intro name menu must be unique')
        return hits if crystal else hits[0]
    if edition=='crystal':
        old=locate(en,english);new=locate(es,spanish);variants=[];proof={}
        expected=[['CHRIS','MAT','ALLAN','JON'],['KRIS','AMANDA','JUANA','JODI']]
        for index,((source,a),(target,b)) in enumerate(zip(old,new)):
            if source!={'items':['NEW NAME']+expected[index],'title':' NAME ','titleX':2}:
                raise ValueError('English Crystal intro name menu differs')
            target['sourceItems']=source['items'];variants.append(target)
            proof[str(index)]={'english':a,'spanish':b}
        return {'variants':variants},proof
    old,a=locate(en,english);new,b=locate(es,spanish)
    presets={'gold':['GOLD','HIRO','TAYLOR','KARL'],'silver':['SILVER','KAMON','OSCAR','MAX']}
    if old!={'items':['NEW NAME']+presets[edition],'title':'NAME','titleX':2}:
        raise ValueError('English intro name menu differs')
    if not 0<=new['titleX']<=10:raise ValueError('intro title indent outside menu')
    new['sourceItems']=old['items']
    return new,{'menu':{'english':a['menu'],'spanish':b['menu']},
        'items':{'english':a['items'],'spanish':b['items']},
        'title':{'english':a['title'],'spanish':b['title']}}


def extract_naming_labels(en,es,english,spanish):
    expected=['YOUR NAME?',"RIVAL'S NAME?","MOTHER'S NAME?",'BOX NAME?']
    def locate(rom,charmap):
        hits=[]
        for address in range(0x4000,0x8000-13):
            start=offset(4,address);raw=rom[start:start+13]
            if not native_match(raw[:4],bytes.fromhex('21cdc311'),rom) or not native_match(raw[6:10],bytes.fromhex('cd740fcd'),rom) or raw[12]!=0xc9:continue
            pointer=raw[4]+256*raw[5]
            if pointer!=address+13:continue
            value,_=name_record(rom,4,pointer,charmap)
            hits.append((value,(4,pointer)))
        if len(hits)!=4:raise ValueError('naming prompt references must be unique four-entry group')
        return hits
    records=[];proof={}
    for source,(original,a),(translated,b) in zip(expected,locate(en,english),locate(es,spanish)):
        if original!=source:raise ValueError('English naming prompt order differs')
        label='NamingPrompts/'+source
        records.append({'label':label,'english':source,'spanish':translated,'original_slots':[],'spanish_slots':[]})
        proof[label]={'english':key(a),'spanish':key(b)}
    possessive,possessive_proof=extract_native_print_labels(en,es,english,spanish,
        [("'S",4,'21cdc3cd740f696011','cd740f1321f5c3cd740f')],prefix='NamingPossessive')
    a=tuple(int(n,16) for n in possessive_proof["NamingPossessive/'S"]['english'].split(':'))
    b=tuple(int(n,16) for n in possessive_proof["NamingPossessive/'S"]['spanish'].split(':'))
    original,pa=name_record(en,*a,english);translated,pb=name_record(es,*b,spanish)
    old,_=name_record(en,4,pa,english);new,_=name_record(es,4,pb,spanish)
    if old!='NICKNAME?':raise ValueError('English nickname prompt differs')
    records.append({'label':'NamingPrompts/NICKNAME?','english':old,'spanish':new,'original_slots':[],'spanish_slots':[]})
    proof['NamingPrompts/NICKNAME?']={'english':key((4,pa)),'spanish':key((4,pb))}
    # Native suffix follows the species name, including the original spacing.
    records.append({'label':'NamingPrompts/possessive','english':"%s'S",'spanish':'%s'+translated,'original_slots':[],'spanish_slots':[]})
    proof['NamingPrompts/possessive']=possessive_proof["NamingPossessive/'S"]
    return records,proof


def extract_naming_grids(en,es,english,spanish,validate=True):
    def locate(rom):
        hits=[]
        prefix=bytes.fromhex('2164ce7eee01772807')
        for address in range(0x4000,0x8000-23):
            start=offset(4,address);raw=rom[start:start+23]
            if not native_match(raw[:9],prefix,rom) or raw[9]!=0x11 or raw[12]!=0xcd or not native_match(raw[15:17],bytes.fromhex('c911'),rom) or raw[19]!=0xcd or raw[22]!=0xc9:continue
            if raw[13:15]!=raw[20:22]:continue
            lower=raw[10]+256*raw[11];upper=raw[17]+256*raw[18]
            mode=raw[13]+256*raw[14];code=rom[offset(4,mode):offset(4,mode)+11]
            if code[0]!=0xcd or not native_match(code[3:6],bytes.fromhex('200621'),rom):continue
            if not native_match(code[8:],bytes.fromhex('19545d'),rom):continue
            delta=code[6]+256*code[7]
            if delta!=85:raise ValueError('naming box table offset differs')
            hits.append({'name_lower':lower,'name_upper':upper,'box_lower':lower+delta,'box_upper':upper+delta})
        if len(hits)!=1:raise ValueError('naming case selector must be unique')
        return hits[0]
    old,new=locate(en),locate(es);grids={};proof={}
    for ident in old:
        rows=5 if ident.startswith('box') else 4
        def read(rom,ptr,charmap):
            start=offset(4,ptr);raw=rom[start:start+(rows+1)*17]
            if len(raw)!=(rows+1)*17:raise ValueError('truncated naming grid')
            return [[charmap[c] for c in raw[row*17:(row+1)*17]] for row in range(rows+1)]
        source=read(en,old[ident],english);target=read(es,new[ident],spanish)
        if validate:
            alphabet='abcdefghijklmnopqrstuvwxyz' if ident.endswith('lower') else 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
            if ''.join(source[0][::2])!=alphabet[:9]:raise ValueError('English naming grid identity differs')
            if ''.join(source[-1]).split()!=(['UPPER','DEL','END'] if ident.endswith('lower') else ['lower','DEL','END']):raise ValueError('English naming actions differ')
        step=1 if ident.startswith('box') else 2
        if validate and step==1 and native_bytes(es,bytes.fromhex('1018202830384048505860687000000000303030306060606060')) not in es[0x10000:0x14000]:
            raise ValueError('Spanish box cursor geometry differs')
        bottom=[];line=target[-1];index=0
        while index<17:
            if line[index]==' ':index+=1;continue
            begin=index
            while index<17 and line[index]!=' ':index+=1
            bottom.append({'x':begin,'text':''.join(line[begin:index])})
        grids[ident]={'rows':[row[2:15] if step==1 else row[::2] for row in target[:-1]],'step':step,'origin':4 if step==1 else 2,'bottom':bottom,'targets':[0,5,9] if step==1 else [0,3,6]}
        proof[ident]={'english':key((4,old[ident])),'spanish':key((4,new[ident])),'row_width':17}
    return grids,proof


def extract_egg_flavor(en,es,english,spanish,expected=None):
    expected=expected or ["It's making sounds<NEXT>inside. It's going<NEXT>to hatch soon!",
        'It moves around<NEXT>inside sometimes.<NEXT>It must be close<NEXT>to hatching.',
        "Wonder what's<NEXT>inside? It needs<NEXT>more time, though.",
        'This EGG needs a<NEXT>lot more time to<NEXT>hatch.']
    def locate(rom,charmap):
        bank=19 if rom[0x134:0x13e]==b'PM_CRYSTAL' else 20
        hits=[]
        for address in range(0x4000,0x8000-33):
            start=offset(bank,address);raw=rom[start:start+33]
            if not native_match(raw[:3],bytes.fromhex('fa26d0'),rom):continue
            if any(raw[pos]!=0x11 for pos in (3,10,17,24)):continue
            if any(not native_match(raw[pos:pos+4],bytes.fromhex(tail),rom) for pos,tail in
                [(6,'fe063811'),(13,'fe0b380a'),(20,'fe293803')]):continue
            if not native_match(raw[27:33],bytes.fromhex('2155c4cd740f'),rom):continue
            values=[]
            for pos in (4,11,18,25):
                pointer=raw[pos]+256*raw[pos+1]
                value,_=name_record(rom,bank,pointer,charmap,128)
                values.append((value,(bank,pointer)))
            hits.append(values)
        if len(hits)!=1:raise ValueError('egg hatch-cycle selector must be unique')
        return hits[0]
    records=[];proof={}
    for index,(source,(original,a),(translated,b)) in enumerate(zip(expected,locate(en,english),locate(es,spanish))):
        if original!=source:raise ValueError('English egg flavor differs')
        label='EggFlavor/'+str(index)
        records.append({'label':label,'english':source,'spanish':translated,'original_slots':[],'spanish_slots':[]})
        proof[label]={'english':key(a),'spanish':key(b)}
    return records,proof


def extract_photo_labels(en,es,english,spanish):
    # These native font tiles are compound glyphs, not the name decoder's
    # printable stand-ins. Preserve the original Spanish ordering and space.
    english=dict(english);spanish=dict(spanish)
    for charmap in (english,spanish):charmap.update({0x73:'<ID>',0x74:'№'})
    bank=0x77 if en[0x134:0x13e]==b'PM_CRYSTAL' else 0x70
    rows,proof=extract_native_print_labels(en,es,english,spanish,[
        ('OT/',bank,'2155c411','cd740f214adb'),
        ('<ID>№.' if bank==0x77 else '<ID>№',bank,'217dc411','cd740f2180c4'),
        ('MOVE',bank,'21b9c411','cd740f21bfc4'),
    ],prefix='PhotoLabels')

    if bank==0x77:
        row=next(r for r in rows if r['english']=='<ID>№.')
        rows.append(dict(row,label='PhotoLabels/engine-ID',english='<ID>№'))
        proof['PhotoLabels/engine-ID']=dict(proof['PhotoLabels/<ID>№.'],alias='port photo label omits original final dot')
    return rows,proof


def extract_trade_stats(en,es,english,spanish):
    """Follow the trade window's own Textbox/PlaceString reference in each ROM."""
    bank=10
    prefix=bytes.fromhex('21a3c306060e0dcdef0e21a4c311')
    suffix=bytes.fromhex('cd740fc9')
    def locate(rom,charmap):
        hits=[]
        for address in range(0x4000,0x8000-len(prefix)-2-len(suffix)):
            start=offset(bank,address);mid=start+len(prefix)
            if not native_match(rom[start:mid],prefix,rom) or not native_match(rom[mid+2:mid+2+len(suffix)],suffix,rom):continue
            pointer=word(rom,bank,address+len(prefix))
            template,_=name_record(rom,bank,pointer,charmap,64)
            rows=template.split('<NEXT>')
            if len(rows)!=4 or rows[1]!='' or not rows[0].startswith('─── ') or not rows[2].endswith('/'):
                raise ValueError('native trade stats template differs')
            hits.append((rows[2],(bank,pointer)))
        if len(hits)!=1:raise ValueError('native trade stats reference must be unique')
        return hits[0]
    (original,a),(translated,b)=locate(en,english),locate(es,spanish)
    if original!='OT/':raise ValueError('English trade OT heading differs')
    label='TradeStats/OT/'
    return ([{'label':label,'english':original,'spanish':translated,'context':'trade.stats',
              'original_slots':[],'spanish_slots':[]}],
            {label:{'english':key(a),'spanish':key(b)}})


def extract_summary_details(en,es,english,spanish,specs=None):
    if specs is None and en[0x134:0x13e]==b'PM_CRYSTAL':
        # Crystal has no Gold ATTK/ printer in this routine. The engine
        # still draws the Gold layout; audit that port-only label separately.
        specs=[
            ('ITEM',19,'11','2140c4cd740fcd'),
            ('MOVE',19,'11','2168c4cd740f2110d1'),
            ('OT/',19,'11','2190c4cd740f216ac4010582'),
            ('Where?',4,'2191c411','cd740fc3'),
        ]
    specs=specs or [
        ('ITEM',20,'2140c411','cd740ffa0cd0a711'),
        ('MOVE',20,'2168c411','cd740f2170c43e28ead3d0'),
        ('OT/',20,'2190c411','cd740f216ac41111d0010582'),
        ('ATTK/',4,'219bc411','cd740ffa60ce472192c43e2a'),
        ('Where?',4,'2191c411','cd740fc3'),
    ]
    return extract_native_print_labels(en,es,english,spanish,specs,context='summary.labels',prefix='SummaryDetails')


def extract_native_print_labels(en,es,english,spanish,specs,context=None,prefix='NativePrint',limit=32):
    label_prefix=prefix
    records=[];proof={}
    for expected,bank,prefix,suffix in specs:
        prefix=bytes.fromhex(prefix);suffix=bytes.fromhex(suffix)
        def locate(rom,charmap):
            hits=[]
            for address in range(0x4000,0x8000-len(prefix)-2-len(suffix)):
                start=offset(bank,address);mid=start+len(prefix)
                if not native_match(rom[start:mid],prefix,rom) or not native_match(rom[mid+2:mid+2+len(suffix)],suffix,rom):continue
                pointer=word(rom,bank,address+len(prefix))
                value,_=name_record(rom,bank,pointer,charmap,limit)
                hits.append((value,(bank,pointer)))
            if len(hits)!=1:raise ValueError('native print reference must be unique: '+expected)
            return hits[0]
        (original,a),(translated,b)=locate(en,english),locate(es,spanish)
        if original!=expected:raise ValueError('English native print label differs: '+repr(expected)+' != '+repr(original))
        label=label_prefix+'/'+expected
        record={'label':label,'english':original,'spanish':translated,'original_slots':[],'spanish_slots':[]}
        if context:record['context']=context
        records.append(record)
        proof[label]={'english':key(a),'spanish':key(b)}
    return records,proof


def extract_party_prompts(en,es,english,spanish,expected=None):
    expected=expected or ['Choose a POKéMON.','Use on which <PK><MN>?','Which <PK><MN>?','Teach which <PK><MN>?',
        'Move to where?','Choose a ♀<PK><MN>.','Choose a ♂<PK><MN>.','To which <PK><MN>?','You have no <PK><MN>!']
    def locate(rom,charmap):
        bank=0x14;hits=[]
        for address in range(0x4008,0x8000-13):
            start=offset(bank,address)
            if native_match(rom[start:start+3],bytes.fromhex('e60f21'),rom) and native_match(rom[start+5:start+13],bytes.fromhex('5f160019192a565f'),rom):
                table=word(rom,bank,address+3)
                pointer=word(rom,bank,table)
                if pointer!=table+18:raise ValueError('party prompt table boundary differs')
                values=[];pointers=[]
                for _ in range(9):
                    old=pointer;text,pointer=name_record(rom,bank,pointer,charmap)
                    values.append((text,(bank,old)));pointers.append(old)
                actual=[word(rom,bank,table+i*2) for i in range(9)]
                if actual!=[pointers[i] for i in [0,1,2,3,4,1,0,0,7]]:
                    raise ValueError('party prompt aliases differ')
                if (rom[start-8]!=0x11 or rom[start-5]!=0x18 or start-3+rom[start-4]!=start+13
                        or word(rom,bank,address-7)!=pointers[8]):
                    raise ValueError('empty party native branch differs')
                hits.append(values)
        if len(hits)!=1:raise ValueError('party prompt table lookup must be unique')
        return hits[0]
    old,new=locate(en,english),locate(es,spanish)
    records=[];proof={}
    for source,(original,a),(translated,b) in zip(expected,old,new):
        if original!=source:raise ValueError('English party prompt differs')
        label='PartyPrompts/'+original
        records.append({'label':label,'english':original,'spanish':translated,'original_slots':[],'spanish_slots':[]})
        proof[label]={'english':key(a),'spanish':key(b)}
    return records,proof


def extract_battle_menu(en,es,english,spanish,contest=False):
    # The 2x2 static menu has no callback; its text follows its header/data.
    def locate(rom,charmap):
        bank=9;hits=[]
        for address in range(0x4000,0x8000-17):
            start=offset(bank,address)
            if (rom[start:start+2]!=bytes([64,12]) or rom[start+3:start+5]!=bytes([17,19])
                    or word(rom,bank,address+5)!=address+8
                    or rom[start+7:start+10]!=bytes([1,129,34])
                    or rom[start+11]!=bank or word(rom,bank,address+12)!=address+17
                    or rom[start+14]!=bank):continue
            callback=word(rom,bank,address+15)
            if bool(callback)!=contest:continue
            cursor=address+17;values=[]
            for _ in range(4):
                pointer=cursor;value,cursor=name_record(rom,bank,cursor,charmap)
                values.append((value,(bank,pointer)))
            if contest:
                if callback!=cursor:continue
                target=offset(bank,callback)
                # The fixed two-digit counter is drawn at (13,16).
                if (not native_match(rom[target:target+10],bytes.fromhex('21edc411c3d9010281cd'),rom)
                        or rom[target+12]!=0xc9):continue
            # Both originals keep the second text column at 16.
            if rom[start+2]+2+rom[start+10]!=16:continue
            hits.append((values,(bank,address)))
        if len(hits)!=1:raise ValueError('battle menu 2D header must be unique')
        return hits[0]
    (old,old_ref),(new,new_ref)=locate(en,english),locate(es,spanish)
    records=[];proof={}
    for expected,(original,a),(translated,b) in zip(['FIGHT','<PK><MN>','PARKBALL×  ' if contest else 'PACK','RUN'],old,new):
        if original!=expected:raise ValueError('English battle menu differs')
        label=('ContestBattleMenu/' if contest else 'BattleMenu/')+original
        context='battle.actions'
        if contest and original=='PARKBALL×  ':
            if not translated.endswith('×  '):raise ValueError('contest counter padding differs')
            original=original.rstrip()+'%02d';translated=translated.rstrip()+'%02d';context=None
        record={'label':label,'english':original,'spanish':translated,'original_slots':[],'spanish_slots':[]}
        if context:record['context']=context
        records.append(record)
        proof[label]={'english':key(a),'spanish':key(b),'english_reference':key(old_ref),'spanish_reference':key(new_ref)}
    return records,proof


def extract_pack_menu_labels(en,es,english,spanish,expected=('USE','GIVE','TOSS','SEL','QUIT'),bank=4,prefix='PackMenu',header_flags=0x40,text_flags=0xc0,context=None):
    # The five-option key-item submenu is unique in bank 4. Spanish changes
    # its coordinates, so match flags/count/default and the self-relative
    # MenuData pointer, never the English screen position or string lengths.
    def locate(rom,charmap):
        candidates=[]
        for address in range(0x4000 if bank else 0,0x8000-10 if bank else 0x4000-10):
            start=offset(bank,address)
            if (rom[start]==header_flags and rom[start+7:start+10]==bytes([1,text_flags,len(expected)])
                    and word(rom,bank,address+5)==address+8):
                names=[];points=[];p=address+10
                for _ in range(len(expected)):
                    points.append((bank,p));name,p=name_record(rom,bank,p,charmap);names.append(name)
                candidates.append((names,points))
        if len(candidates)!=1:raise ValueError('pack submenu must be unique')
        return candidates[0]
    originals,a=locate(en,english);translations,b=locate(es,spanish)
    if originals!=list(expected):raise ValueError('English pack submenu differs')
    records=[];proof={}
    for i,original in enumerate(originals):
        label=prefix+'/'+original
        record={'label':label,'english':original,'spanish':translations[i],'original_slots':[],'spanish_slots':[]}
        if context:record['context']=context
        records.append(record)
        proof[label]={'english':key(a[i]),'spanish':key(b[i])}
    return records,proof


def extract_ui_labels(en,es,manifest,english,spanish,stat_point=(0x0d,0x65c5)):
    records=[];proof={}
    def record(label,a,b,original,translated):
        if not translated:return  # unused BIRD has no Spanish display name
        records.append({'label':label,'english':original,'spanish':translated,'original_slots':[],'spanish_slots':[]})
        proof[label]={'english':key(a),'spanish':key(b)}
    bank,address=manifest['symbols']['TypeNames']
    count=max(manifest['constants']['types'].values())+1
    for rom in (en,es):
        if word(rom,bank,address)!=address+2*count:raise ValueError('type table boundary mismatch')
    for name,index in sorted(manifest['constants']['types'].items()):
        a=(bank,word(en,bank,address+index*2));b=(bank,word(es,bank,address+index*2))
        original,_=name_record(en,*a,english);translated,_=name_record(es,*b,spanish)
        expected={'PSYCHIC_TYPE':'PSYCHIC','CURSE_TYPE':'???'}.get(name,name)
        if original!=expected:raise ValueError('English type name differs: '+name)
        record('TypeNames/'+name,a,b,original,translated)
    bank,address=stat_point
    crystal=en[0x134:0x13e]==b'PM_CRYSTAL'
    target=address
    if crystal:
        # This table remains in bank 0d, but its address and the loader's
        # scratch buffers relocate. Pair its native character-search loop.
        seed=bytes.fromhex('80939380828a50838485848d928450')
        start=offset(bank,0x4000);end=start+0x4000
        positions=[p for p in range(start,end-len(seed)+1) if en[p:p+len(seed)]==seed]
        if len(positions)!=1:raise ValueError('Crystal stat table seed must be unique')
        address=positions[0]-start+0x4000
        pointer=bytes([0x21,address&255,address>>8])
        refs=[p for p in range(start,end-20) if en[p:p+3]==pointer]
        if len(refs)!=1:raise ValueError('Crystal stat table loader must be unique')
        suffix=bytes.fromhex('0e500528062ab928f918fa11')
        if en[refs[0]+3:refs[0]+3+len(suffix)]!=suffix:
            raise ValueError('Crystal stat table loader search loop differs')
        refs=[p for p in range(start,end-20) if es[p]==0x21 and es[p+3:p+3+len(suffix)]==suffix]
        if len(refs)!=1:raise ValueError('Spanish Crystal stat table loader must be unique')
        target=int.from_bytes(es[refs[0]+1:refs[0]+3],'little')
    else:
        pointer=bytes([0x21,address&255,address>>8])
        anchor=en.find(pointer)
        if anchor<0 or en.find(pointer,anchor+1)>=0 or es[anchor:anchor+3]!=pointer:
            raise ValueError('stat-name native pointer anchor differs')
    a=address;b=target
    for expected in ['ATTACK','DEFENSE','SPEED','SPCL.ATK','SPCL.DEF','ACCURACY','EVASION','ABILITY']:
        old_a=a;old_b=b
        original,a=name_record(en,bank,a,english);translated,b=name_record(es,bank,b,spanish)
        if original!=expected:raise ValueError('English stat table differs')
        record('StatNames/'+expected,(bank,old_a),(bank,old_b),original,translated)
    return records,proof


def character_maps(manifest):
    english={int(k):v for k,v in manifest['charmap'].items()}
    spanish=dict(english)
    # Latin European Gold character codes, verified against source-ROM text.
    for code,ch in {0xba:'à',0xbb:'è',0xbc:'é',0xbd:'ù',0xbe:'À',0xbf:'Á',0xc0:'Ä',0xc1:'Ö',0xc2:'Ü',0xc3:'ä',0xc4:'ö',0xc5:'ü',0xc6:'È',0xc7:'É',0xc8:'Ì',0xc9:'Í',0xca:'Ñ',0xcb:'Ò',0xcc:'Ó',0xcd:'Ù',0xce:'Ú',0xcf:'á',0xd0:'ì',0xd1:'í',0xd2:'ñ',0xd3:'ò',0xd4:'ó',0xd5:'ú',0xd6:'°',0xd8:"'d",0xd9:"'l",0xda:"'m",0xdb:"'r",0xdc:"'s",0xdd:"'t",0xde:"'v",0xdf:'←',0xe0:"'",0xe3:'-',0xe4:'¿',0xe5:'¡',0xe6:'?',0xe7:'!',0xe8:'.',0xe9:'&',0xea:'é',0xeb:'→',0xed:'▶',0xee:'▼',0xef:'♂',0xf0:'¥',0xf1:'×',0xf2:'.',0xf3:'/',0xf4:',',0xf5:'♀'}.items():spanish[code]=ch
    for n in range(10):spanish[0xf6+n]=str(n)
    return english,spanish


SPANISH_SHA1 = {
    'gold': '162ea54c6a3cff374642e6dd842f9bffac847e7b',
    'silver': '05bd978ab2cb104b0aff3f696896e30885203a18',
    'crystal': '889a06fc0bb863666865aa69def0adf97945ac2a',
}


def variant_manifest(engine, edition, en, es):
    manifest=json.loads((engine/f'tools/rom_manifest_{edition}.json').read_text())
    sha=hashlib.sha1(en).hexdigest()
    if sha!=manifest['romSha1'] and sha not in manifest.get('symbolRevisions',{}):
        raise ValueError('English ROM does not match engine manifest')
    if hashlib.sha1(es).hexdigest()!=SPANISH_SHA1[edition]:
        raise ValueError('Spanish ROM does not match the verified original '+edition+' release')
    manifest['symbols'].update(manifest.get('symbolRevisions',{}).get(sha,{}))
    return manifest


def extract_mail_messages(mapper,en,es,english,spanish):
    catalog,proof={},[]
    for pair in mapper.mail_pairs:
        a=tuple(int(v,16) for v in pair['english'].split(':'))
        b=tuple(int(v,16) for v in pair['spanish'].split(':'))
        if pair['command']=='givepokemail':
            if byte(en,*a)!=byte(es,*b):raise ValueError('Paired mail item differs')
            a=(a[0],a[1]+1);b=(b[0],b[1]+1)
        old,_=name_record(en,*a,{**english,0x4e:'\n',0x4f:'\n'},64)
        new,_=name_record(es,*b,{**spanish,0x4e:'\n',0x4f:'\n'},64)
        old=old.replace('<NEXT>','\n');new=new.replace('<NEXT>','\n')
        if old in catalog and catalog[old]!=new:raise ValueError('Conflicting native mail translation')
        catalog[old]=new
        proof.append(dict(pair,message_english=key(a),message_spanish=key(b),original=old,translated=new))
    if not catalog or {p['command']for p in proof}!={'givepokemail','checkpokemail'}:
        raise ValueError('Gift/recipient mail correspondence missing')
    return catalog,proof


def write_mail_output(output,edition,en,es,catalog,proof):
    write_catalog(output/'lang/mail_messages.lua',catalog)
    (output/'mail-provenance.json').write_text(json.dumps({
        'game':edition,'rom_sha1':{'english':hashlib.sha1(en).hexdigest(),'spanish':hashlib.sha1(es).hexdigest()},
        'mail':proof},ensure_ascii=False,indent=2)+'\n')


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--engine',type=Path,required=True)
    parser.add_argument('--english-rom',type=Path,required=True)
    parser.add_argument('--spanish-rom',type=Path,required=True)
    parser.add_argument('--cache',type=Path,required=True,help='English text/rom_text JSON, exported with export_cache.lua')
    parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--game',choices=tuple(SPANISH_SHA1),default='gold')
    args=parser.parse_args()
    en=args.english_rom.read_bytes();es=args.spanish_rom.read_bytes()
    manifest=variant_manifest(args.engine,args.game,en,es)
    (args.output/'lang').mkdir(parents=True,exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        metadata=Path(tmp)/'maps.json'
        subprocess.run(['luajit',str(Path(__file__).with_name('export.lua')),str(args.engine),str(args.english_rom),str(args.spanish_rom),str(metadata),args.game,hashlib.sha1(en).hexdigest()],check=True)
        maps=json.loads(metadata.read_text())
    mapper=Mapper(en,es,{int(k):v for k,v in maps['opcodes'].items()});mapper.maps(maps)
    mapper.phone(manifest)
    mapper.hall_of_fame(manifest)
    english,spanish=character_maps(manifest)
    mapper.resolve_identical_copies(spanish)
    mail,mail_sources=extract_mail_messages(mapper,en,es,english,spanish)
    write_mail_output(args.output,args.game,en,es,mail,mail_sources)
    cache=json.loads(args.cache.read_text());dialogue={};rom_text={};provenance={};rejected=[]
    common_tables(mapper,manifest['symbols'],cache['rom_text'],english,spanish,
                  banks=(0x6f,0x70,0x71) if args.game=='crystal' else (0x64,0x65,0x66))
    anchored_text_blocks(mapper,manifest['symbols'],cache['rom_text'],english,spanish,
                         banks=(0x20,0x6c) if args.game=='crystal' else (0x40,))
    if args.game=='crystal':
        entries={k:v for k,v in cache['dialogue'].items() if isinstance(v,str) and v and re.fullmatch('[0-9a-f]{2}:[0-9a-f]{4}',k)}
        points={k:tuple(int(n,16) for n in k.split(':')) for k in entries}
        anchored_text_blocks(mapper,points,entries,english,spanish,banks=sorted({p[0] for p in points.values()}),strict=False)
    mapper.far_texts([tuple(int(v,16) for v in ident.split(':')) for ident in cache['dialogue'] if re.fullmatch('[0-9a-f]{2}:[0-9a-f]{4}',ident)])
    map_dialogue={}
    for point in sorted(mapper.conflicts):
        contexts=mapper.context_targets.get(point,{})
        targets=set().union(*contexts.values()) if contexts else set()
        if targets!=mapper.targets[point] or any(len(v)!=1 for v in contexts.values()):continue
        source_slots=[];decode(en,*point,english,slots=source_slots)
        copies={}
        for context,points in contexts.items():
            target=next(iter(points));slots=[];body,_=decode(es,*target,spanish,slots=slots)
            if slots!=source_slots:break
            copies[context]=body
        else:
            for context,body in copies.items():
                map_dialogue.setdefault(context,{})[key(point)]=body
                native=maps['en'][context]
                identity=str(native['group'])+':'+str(native['map'])
                map_dialogue.setdefault(identity,{})[key(point)]=body
            mapper.conflicts.remove(point)
            mapper.sources[point]+=' / map-specific original Spanish copies'
    write_catalog(args.output/'lang/map_dialogue.lua',map_dialogue)
    labels_by_point={tuple(point):label for label,point in manifest['symbols'].items()}
    phone_points={(0x19,0x717a),(0x5d,0x6816),(0x6d,0x75e5)} if args.game=='crystal' else set()
    def translate(a,source,positional=False):
        if a not in mapper.pairs or a in mapper.conflicts:return None
        b=mapper.pairs[a]
        try:
            en_operands=[];es_operands=[];en_slots=[];es_slots=[]
            original,_=decode(en,*a,english,en_operands,en_slots);translated,_=decode(es,*b,spanish,es_operands,es_slots)
            phone=a in phone_points
            if en_operands!=es_operands and not positional and not phone:raise ValueError('runtime buffer identity/order mismatch')
            if args.game=='crystal' and positional:es_slots=seer_slots(labels_by_point.get(a),es_slots)
            if original!=source:
                legacy,_=decode(en,*a,english,preserve_scroll=False)
                if source not in (original.replace('{DAY}',''),legacy,legacy.replace('{DAY}','')):
                    raise ValueError('English decoder differs from current cache')
            translated=terminal(translated)+original[len(terminal(original)):]
            source_tokens=tokens(original);target_tokens=tokens(translated)
            if not positional:
                for optional in ('{PLAYER}','{RIVAL}'):
                    if target_tokens[optional]<=source_tokens[optional]:
                        source_tokens.pop(optional,None);target_tokens.pop(optional,None)
            if phone:
                if any(slot not in en_slots for slot in es_slots):raise ValueError('unknown phone field')
                translated=phone_buffer_text(translated,es_slots)
            elif not translated or source_tokens!=target_tokens:raise ValueError('runtime placeholder mismatch')
            if positional and en_slots!=es_slots:
                translated=positional_text(translated,en_slots,es_slots)
        except (ValueError,IndexError) as exc:
            rejected.append({'english':key(a),'spanish':key(b),'reason':str(exc)});return None
        provenance[key(a)]={'spanish':key(b),'source':mapper.sources[a]}
        return translated
    for ident,source in sorted(cache['dialogue'].items()):
        if not re.fullmatch('[0-9a-f]{2}:[0-9a-f]{4}',ident):continue
        a=tuple(int(v,16) for v in ident.split(':'));translated=translate(a,source)
        if translated is not None:dialogue[ident]=translated
    for label,source in sorted(cache['rom_text'].items()):
        point=manifest['symbols'].get(label)
        if point:
            translated=translate(tuple(point),source,positional=True)
            if translated is not None:rom_text[label]=translated
    write_catalog(args.output/'lang/dialogue.lua',dialogue)
    write_catalog(args.output/'lang/rom_text.lua',rom_text)
    text_audit={
        'game':args.game,'dialogue':len(dialogue),'rom_text':len(rom_text),
        'untranslated':{
            'dialogue':{k:v for k,v in cache['dialogue'].items() if re.fullmatch('[0-9a-f]{2}:[0-9a-f]{4}',k) and v and k not in dialogue},
            'rom_text':{k:v for k,v in cache['rom_text'].items() if v and k not in rom_text},
        },'rejected':rejected,'script_mismatches':mapper.rejected,
        'provenance':provenance,
    }
    (args.output/'text-audit.json').write_text(json.dumps(text_audit,ensure_ascii=False,indent=2)+'\n')
    font_raw,font_sources=extract_font_graphics(en,es,manifest)
    font_bank,font_address=manifest['symbols']['Font']
    font_start=offset(font_bank,font_address)
    battle_raw,battle_sources=extract_battle_font_graphics(en,es,manifest)
    battle_bank,battle_address=manifest['symbols']['FontBattleExtra']
    battle_start=offset(battle_bank,battle_address)
    recipe='local main=(function()\n'+font_transform(en[font_start:font_start+1024],font_raw)+'end)()\n'
    recipe+='local battle=(function()\n'+battle_font_transform(en[battle_start:battle_start+400],battle_raw)+'end)()\n'
    recipe+='return function(ctx) main(ctx);battle(ctx) end\n'
    (args.output/'font_transforms.lua').write_text(recipe,encoding='utf-8')
    font_charmap={seq:code for code,seq in sorted(spanish.items()) if code>=0x80 and seq!=english.get(code)}
    write_catalog(args.output/'lang/font_charmap.lua',font_charmap)
    pack_raw,pack_graphics_sources=extract_pack_graphics(en,es,manifest)
    pack_path=args.output/'overrides/pack/menu.png'
    pack_path.parent.mkdir(parents=True,exist_ok=True)
    pack_path.write_bytes(tile_png(pack_raw,128,48))
    dex_raw,dex_graphics_sources=extract_pokedex_graphics(en,es,manifest,lambda data:decompress_lz3(data,args.engine))
    dex_path=args.output/'overrides/pokedex/dex.png'
    dex_path.parent.mkdir(parents=True,exist_ok=True)
    dex_path.write_bytes(tile_png(dex_raw,128,32))
    gear_raw,gear_graphics_sources=extract_pokegear_graphics(en,es,manifest,lambda data:decompress_lz3(data,args.engine))
    gear_path=args.output/'overrides/pokegear/gear.png'
    gear_path.parent.mkdir(parents=True,exist_ok=True)
    gear_path.write_bytes(tile_png(gear_raw,128,48))
    title_dir=args.output/'overrides/title'
    title_dir.mkdir(parents=True,exist_ok=True)
    if args.game=='crystal':
        images,title_graphics_sources=extract_crystal_title_graphics(en,es,manifest,args.engine)
        for filename,raw in images.items():(title_dir/filename).write_bytes(raw)
    else:
        title_raw,title_gray_raw,title_graphics_sources=extract_title_graphics(en,es,manifest,args.engine,args.game)
        (title_dir/'title_screen.png').write_bytes(title_raw)
        (title_dir/'title_screen_gray.png').write_bytes(title_gray_raw)
    images,ui_layout,certificate_sources=extract_certificate_graphics(en,es,manifest,args.engine,english,spanish)
    for filename,raw in images.items():
        target=args.output/'overrides'/filename;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(raw)
    write_catalog(args.output/'lang/ui_layout.lua',ui_layout)
    gamefreak_splash_sources=audit_gamefreak_splash(en,es,manifest)
    phone_names,phone_name_sources=extract_phone_names(en,es,manifest,english,spanish)
    write_catalog(args.output/'lang/phone_contacts_names.lua',phone_names)
    radio_names,radio_sources=extract_radio_station_names(en,es,english,spanish)
    write_catalog(args.output/'lang/radio_channels_names.lua',radio_names)
    pokedex_entries,pokedex_sources=extract_pokedex_entries(en,es,manifest,english,spanish)
    write_catalog(args.output/'lang/pokedex_entries.lua',pokedex_entries)
    descriptions,description_sources=extract_descriptions(en,es,manifest,english,spanish,cache)
    for name,values in descriptions.items():write_catalog(args.output/('lang/'+name+'.lua'),values)
    sources=harvest_engine_sources(args.engine);records=[]
    seer_name_sources={}
    if args.game=='crystal':
        seer_names,seer_name_sources=extract_seer_names(en,es,english,spanish)
        records.extend(seer_names)
    title_summary_labels,title_summary_sources=extract_title_and_summary_labels(
        en,es,english,spanish)
    records.extend(title_summary_labels)
    for label in rom_text:
        a=tuple(manifest['symbols'][label]);b=mapper.pairs[a];aa=[];bb=[]
        original,_=decode(en,*a,english,slots=aa);translated,_=decode(es,*b,spanish,slots=bb)
        if args.game=='crystal':bb=seer_slots(label,bb)
        records.append({'label':label,'english':original,'spanish':translated,'original_slots':aa,'spanish_slots':bb,'english_point':key(a),'spanish_point':key(b)})
    battle_assembled,battle_assembly_sources=assemble_battle_texts(records)
    records.extend(battle_assembled)
    battle_bindings,battle_binding_sources=battle_message_bindings(records)
    held_item_bindings,held_item_sources=bind_held_item_messages(records)
    prize_bindings,prize_sources=bind_prize_messages(records)
    weather_bindings,weather_sources=bind_weather_messages(records)
    stat_charge_bindings,stat_charge_sources=bind_stat_charge_messages(records)
    battler_prefix,battler_prefix_sources=extract_battler_prefix(en,es,english,spanish)
    for label in mapper.hof_references:
        a=tuple(manifest['symbols'][label]);b=mapper.pairs[a]
        original,_=decode(en,*a,english);translated,_=decode(es,*b,spanish)
        records.append({'label':label,'english':original,'spanish':translated,'original_slots':[],'spanish_slots':[]})
    landmark_names,landmark_sources=extract_landmark_names(en,es,manifest,english,spanish)
    write_catalog(args.output/'lang/landmarks_names.lua',landmark_names)
    ui_labels,ui_sources=extract_ui_labels(en,es,manifest,english,spanish)
    ui_sources.update(seer_name_sources)
    pack_labels,pack_sources=extract_pack_menu_labels(en,es,english,spanish)
    yesno_labels,yesno_sources=extract_pack_menu_labels(en,es,english,spanish,expected=("YES","NO"),bank=0,prefix="YesNoMenu")
    cancel_labels,cancel_sources=extract_cancel_label(en,es,english,spanish)
    option_labels,option_sources=extract_option_labels(en,es,english,spanish)
    option_values,value_sources=extract_option_values(en,es,english,spanish)
    start_labels,start_sources=extract_start_menu(en,es,english,spanish)
    contest_labels,contest_sources=extract_contest_status(en,es,english,spanish)
    party_labels,party_sources=extract_party_actions(en,es,english,spanish)
    party_prompts,prompt_sources=extract_party_prompts(en,es,english,spanish)
    compatibility_labels,compatibility_sources=extract_party_compatibility(en,es,english,spanish)
    status_labels,status_sources=extract_fainted_label(en,es,english,spanish)
    condition_labels,condition_sources=extract_status_labels(en,es,english,spanish)
    summary_labels,summary_sources=extract_summary_headings(en,es,english,spanish)
    detail_labels,detail_sources=extract_summary_details(en,es,english,spanish)
    trade_labels,trade_sources=extract_trade_stats(en,es,english,spanish)
    photo_labels,photo_sources=extract_photo_labels(en,es,english,spanish)
    egg_labels,egg_sources=extract_egg_flavor(en,es,english,spanish)
    naming_grids,naming_sources=extract_naming_grids(en,es,english,spanish)
    naming_labels,naming_label_sources=extract_naming_labels(en,es,english,spanish)
    write_catalog(args.output/'lang/naming_grids.lua',naming_grids)
    intro_names,intro_name_sources=extract_intro_names(en,es,english,spanish,args.game)
    pc_labels,pc_sources=extract_pc_menu_labels(en,es,english,spanish)
    storage_labels,storage_sources=extract_storage_captions(en,es,english,spanish)
    storage_actions,storage_action_sources=extract_storage_actions(en,es,english,spanish)
    write_catalog(args.output/'lang/intro_names.lua',intro_names)
    battle_labels,battle_sources=extract_battle_menu(en,es,english,spanish)
    contest_battle_labels,contest_battle_sources=extract_battle_menu(en,es,english,spanish,contest=True)
    move_info_labels,move_info_sources=extract_native_print_labels(en,es,english,spanish,[('Disabled!',15,'2169c411','cd740f18')],prefix='BattleMoveInfo')
    phone_labels,phone_sources=extract_phone_actions(en,es,english,spanish)
    gear_switch_labels,gear_switch_sources=extract_pokegear_switch(en,es,english,spanish)
    dex_nest_labels,dex_nest_sources=extract_pokedex_nest(en,es,english,spanish)
    dex_counter_labels,dex_counter_sources=extract_pokedex_counters(en,es,english,spanish)
    dex_result_labels,dex_result_sources=extract_pokedex_not_found(en,es,english,spanish)
    dex_mode_labels,dex_mode_sources=extract_pokedex_modes(en,es,english,spanish)
    dex_title_labels,dex_title_sources=extract_pokedex_titles(en,es,english,spanish)
    dex_search_labels,dex_search_sources=extract_pokedex_search_labels(en,es,english,spanish)
    dex_size_labels,dex_size_sources=extract_pokedex_size_labels(en,es,english,spanish)
    held_labels,held_sources=extract_pack_menu_labels(en,es,english,spanish,expected=['GIVE','TAKE'],prefix='HeldItemMenu',header_flags=0x50,text_flags=0x80,context='held.actions')
    mail_labels,mail_sources=extract_pack_menu_labels(en,es,english,spanish,expected=['READ','TAKE','QUIT'],prefix='MailMenu',text_flags=0x80,context='mail.actions')
    ui_labels.extend(pack_labels+yesno_labels+cancel_labels+option_labels+option_values+start_labels+contest_labels+party_labels+party_prompts+compatibility_labels+status_labels+condition_labels+summary_labels+detail_labels+trade_labels+photo_labels+egg_labels+naming_labels+pc_labels+storage_labels+storage_actions+battle_bindings+held_item_bindings+battler_prefix+prize_bindings+weather_bindings+stat_charge_bindings+battle_labels+contest_battle_labels+move_info_labels+dex_size_labels+dex_search_labels+dex_title_labels+dex_mode_labels+dex_result_labels+dex_counter_labels+dex_nest_labels+gear_switch_labels+phone_labels+held_labels+mail_labels)
    for proof in (pack_sources,yesno_sources,cancel_sources,option_sources,value_sources,start_sources,contest_sources,party_sources,prompt_sources,compatibility_sources,status_sources,condition_sources,summary_sources,detail_sources,trade_sources,photo_sources,egg_sources,naming_label_sources,pc_sources,storage_sources,storage_action_sources,battle_binding_sources,held_item_sources,battler_prefix_sources,prize_sources,weather_sources,stat_charge_sources,battle_sources,contest_battle_sources,move_info_sources,dex_size_sources,dex_search_sources,dex_title_sources,dex_mode_sources,dex_result_sources,dex_counter_sources,dex_nest_sources,gear_switch_sources,phone_sources,held_sources,mail_sources):ui_sources.update(proof)
    records.extend(r for r in ui_labels if not r.get("context"))
    records.extend(dialogue_engine_records(cache['dialogue'],dialogue))
    records.extend(dialogue_engine_records(cache['rom_text'],rom_text))
    type_names={r['label'].split('/',1)[1]:r['spanish'] for r in ui_labels if r['label'].startswith('TypeNames/')}
    write_catalog(args.output/'lang/type_chart_names.lua',type_names)
    strings,string_sources=engine_strings(sources,records)
    forgot_source='Poof! %s forgot %s!'
    if forgot_source in sources:
        row=next(r for r in records if r['label']=='_MoveForgotText')
        if row['english']!=' Poof!\f{STRBUF} forgot\n{STRBUF}.\fAnd…{PROMPT}':
            raise ValueError('native move-forgetting fallback differs')
        body=positional_text(terminal(row['spanish']),row['original_slots'],row['spanish_slots'])
        strings[forgot_source]=re.sub(r'\{ARG:(\d+)\}',lambda m:'%'+m[1]+'$s',body)
        string_sources[forgot_source]={'engine':sources[forgot_source],'labels':['_MoveForgotText'],
            'match':'native RomText fallback; original page breaks and wording retained'}
    engine_only_ui_sources=add_engine_only_ui_translations(strings,sources)
    string_sources.update(engine_only_ui_sources)
    gen2_literal_sources=add_engine_gen2_literal_translations(strings,sources)
    string_sources.update(gen2_literal_sources)
    for record in ui_labels:
        source=(record['context']+'|' if record.get('context') else '')+record['english']
        strings[source]=record['spanish']
        string_sources[source]={'engine':'native UI label lookup','labels':[record['label']]}
    string_sources.update(bind_native_port_fallbacks(strings,sources,records))
    string_sources.update(reviewed_ui_bindings(strings,sources,records))
    for command in mapper.localized_landmarks:
        ident=manifest['constants']['landmarkOrder'][command['landmark']]
        strings[command['source']]=landmark_names[ident].replace('\n',' ')
        string_sources[command['source']]={'engine':'localized getstring landmark','labels':[ident]}
    literal_candidates={};literal_sources={};literal_rejections=[]
    for pair in mapper.literal_pairs:
        a=tuple(int(v,16) for v in pair['english'].split(':'));b=tuple(int(v,16) for v in pair['spanish'].split(':'))
        try:
            original,_=name_record(en,*a,english,64);translated,_=name_record(es,*b,spanish,64)
            if not original or not translated:continue
        except (ValueError,IndexError) as exc:
            literal_rejections.append(dict(pair,reason=str(exc)));continue
        literal_candidates.setdefault(original,set()).add(translated)
        literal_sources.setdefault(original,[]).append(pair)
    for original,values in sorted(literal_candidates.items()):
        if len(values)!=1:
            literal_rejections.append({'source':original,'reason':'ambiguous literal translations'});continue
        translated=next(iter(values))
        if original in strings and strings[original]!=translated:
            literal_rejections.append({'source':original,'reason':'literal conflicts with existing binding'});continue
        strings[original]=translated
        string_sources[original]={'engine':'script getstring literal','pointers':literal_sources[original]}
    write_catalog(args.output/'lang/strings.lua',strings)
    names,name_locations=extract_names(en,es,manifest,english,spanish)
    trainer_names,trainer_locations=extract_trainer_names(en,es,manifest,english,spanish)
    write_catalog(args.output/'lang/trainer_party_names.lua',trainer_names)
    for name,values in names.items():write_catalog(args.output/('lang/'+name+'.lua'),values)
    write_catalog(args.output/'lang/dialogue.lua',dialogue)
    write_catalog(args.output/'lang/rom_text.lua',rom_text)
    report={'phone_name_sources':phone_name_sources,'pokegear_graphics_sources':gear_graphics_sources,'title_graphics_sources':title_graphics_sources,'gamefreak_splash_sources':gamefreak_splash_sources,'radio_station_sources':radio_sources,'pokedex_graphics_sources':dex_graphics_sources,'pokedex_sources':pokedex_sources,'battle_font_sources':battle_sources,'font_sources':font_sources,'pack_graphics_sources':pack_graphics_sources,'rom_sha1':{'english':hashlib.sha1(en).hexdigest(),'spanish':hashlib.sha1(es).hexdigest()},'maps':len(maps['en']),'phone_table':mapper.phone_table,'localized_landmark_commands':mapper.localized_landmarks,'hall_of_fame_references':mapper.hof_references,'engine_strings':len(strings),'ui_label_sources':ui_sources,'title_summary_sources':title_summary_sources,'engine_only_ui_sources':engine_only_ui_sources,'gen2_literal_sources':gen2_literal_sources,'landmark_sources':landmark_sources,'engine_string_sources':string_sources,'literal_rejections':literal_rejections,'description_sources':description_sources,'descriptions':{name:len(values) for name,values in descriptions.items()},'name_tables':name_locations,'trainer_name_sources':trainer_locations,'trainer_names':sum(len(v) for v in trainer_names.values()),'names':{name:len(values) for name,values in names.items()},'dialogue':len(dialogue),'dialogue_total':sum(bool(re.fullmatch('[0-9a-f]{2}:[0-9a-f]{4}',k)) for k in cache['dialogue']),'rom_text':len(rom_text),'rom_text_total':len(cache['rom_text']),'provenance':provenance,'rejected_text':rejected,'script_mismatches':mapper.rejected,'conflicts':[key(a) for a in sorted(mapper.conflicts)]}
    report['untranslated']={
        'dialogue':{ident:source for ident,source in cache['dialogue'].items() if re.fullmatch('[0-9a-f]{2}:[0-9a-f]{4}',ident) and source and ident not in dialogue},
        'rom_text':{label:source for label,source in cache['rom_text'].items() if source and label not in rom_text},
    }
    report['mail_sources']=mail_sources
    report['certificate_sources']=certificate_sources
    report['naming_grid_sources']=naming_sources
    report['intro_name_sources']=intro_name_sources
    report['battle_assembly_sources']=battle_assembly_sources
    (args.output/'provenance.json').write_text(json.dumps(report,ensure_ascii=False,indent=2,sort_keys=True)+'\n')
    print(f'Copied {len(dialogue)} dialogue and {len(rom_text)} engine ROM strings from {len(maps["en"])} paired maps; {len(rejected)} rejected texts')


if __name__=='__main__':main()
