"""CPU-only address proof/check; explicitly not a substitute for NPU execution."""
import hashlib
import json
from pathlib import Path
import random
import re
import sys
import time
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "reference"))
import golden

TILE = int(re.search(r'kTileElements = (\d+)', (ROOT/'common/t5_plan.h').read_text()).group(1))

def fragments(b, h, l, d, output):
    hd = h*d; qsize = b*hd; size = qsize if output == 0 else qsize*(l+1)
    row = (l+1)*d; old = l*d
    if output and size >= 16*1024*1024 and d % 16 == 0 and l > 0:
        old_tiles = (old+TILE-1)//TILE
        for head in range(b*h):
            for part in range(old_tiles):
                within = part*TILE
                yield head*(old_tiles+1)+part, head*row+within, min(TILE,old-within), output, head*old+within
            batch,index_h = divmod(head,h)
            yield head*(old_tiles+1)+old_tiles, head*row+old, d, 0, batch*3*hd+output*hd+index_h*d
        return
    for start in range(0, size, TILE):
        end = min(start+TILE, size); pos = start
        while pos < end:
            if output == 0 or l == 0:
                batch, within = divmod(pos, hd)
                n = min(end-pos, hd-within); source = 0; src = batch*3*hd+output*hd+within
            else:
                head, within = divmod(pos, row)
                if within < old:
                    n = min(end-pos, old-within); source = output; src = head*old+within
                else:
                    n = min(end-pos, row-within); source = 0
                    batch, head_index = divmod(head, h)
                    src = batch*3*hd+output*hd+head_index*d+within-old
            yield start//TILE, pos, n, source, src
            pos += n

def oracle_address(shape, output, offset):
    b,h,l,d = shape
    index_d = offset % d
    token = (offset//d) % (1 if output == 0 else l+1)
    head = offset//(d*(1 if output == 0 else l+1))
    if output and token < l:
        return output, (head*l+token)*d+index_d
    batch, index_h = divmod(head,h)
    return 0, ((batch*3+output)*h+index_h)*d+index_d

def check(shape, *, bitwise=False):
    b,h,l,d=shape
    input_sizes=[b*3*h*d,b*h*l*d,b*h*l*d]
    output_sizes=[b*h*d,b*h*(l+1)*d,b*h*(l+1)*d]
    assert max(input_sizes+output_sizes) < 2**32
    count=0; outputs=[]
    if bitwise:
        inputs=[(np.arange(n,dtype=np.uint32)*997+i*7919).astype(np.uint16) for i,n in enumerate(input_sizes)]
    for output,size in enumerate(output_sizes):
        cursor=0
        if bitwise: actual=np.empty(size,dtype=np.uint16)
        for tile,pos,n,source,src in fragments(*shape,output):
            assert pos==cursor and n>0 and src>=0 and src+n<=input_sizes[source]
            if output and size >= 16*1024*1024 and d % 16 == 0 and l > 0:
                # Every independent row fragment owns complete 32-byte blocks.
                assert pos % 16 == 0 and n % 16 == 0
            else:
                assert pos//TILE == tile and (pos+n-1)//TILE==tile
            for index in {0,n//2,n-1}:
                assert (source,src+index)==oracle_address(shape,output,pos+index)
            if bitwise: actual[pos:pos+n]=inputs[source][src:src+n]
            cursor+=n; count+=1
        assert cursor==size
        if bitwise: outputs.append(actual)
    if bitwise:
        arrays=[inputs[0].reshape(b,1,3*h*d),inputs[1].reshape(b,h,l,d),inputs[2].reshape(b,h,l,d)]
        expected=golden.calculate(arrays,{})
        for actual,wanted in zip(outputs,expected): assert np.array_equal(actual,wanted.reshape(-1))
    return count

def main():
    start=time.perf_counter(); records=[]
    cases=json.loads((ROOT/'reference/case.json').read_text(encoding='utf-8'))
    for case in cases:
        shape=case['input_desc'][1]['shape']; b,h,l,d=shape
        small=b*h*d*(2*l+3)<=2**23
        count=check(shape,bitwise=small)
        records.append({'case_name':case['case_name'],'shape':shape,'status':'passed',
                        'fragment_count':count,'address_ranges_checked':'all',
                        'bitwise_cpu_arrays':small,'npu_executed':False})
    rng=random.Random(20261028)
    for _ in range(120):
        shape=(rng.randint(1,4),rng.randint(1,8),rng.choice([0,1,2,31,63,128,257]),rng.randint(1,256))
        check(shape,bitwise=True)
    report={'status':'passed','test_type':'CPU address-model checks only','npu_executed':False,
            'public_shapes':len(records),'additional_random_shapes':120,'cases':records,
            'seconds':time.perf_counter()-start}
    out=ROOT/'reports/cpu_address_model.json';out.parent.mkdir(exist_ok=True)
    out.write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({k:v for k,v in report.items() if k!='cases'}))

if __name__=='__main__':main()
