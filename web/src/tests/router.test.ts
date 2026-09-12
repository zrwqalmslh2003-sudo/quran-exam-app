import {describe,expect,it} from 'vitest';
import {parseHash,toHash} from '../state/router';

describe('hash router',()=>{
  it('parses known hashes',()=>{
    expect(parseHash('#/')).toEqual({kind:'home'});
    expect(parseHash('#/categories')).toEqual({kind:'categories'});
    expect(parseHash('#/category/xxx')).toEqual({kind:'category',ref:'xxx'});
    expect(parseHash('#/exam/id/1')).toEqual({kind:'exam',examId:'id',version:1});
    expect(parseHash('#/result')).toEqual({kind:'result'});
  });
  it('normalizes unknown and empty hashes to home',()=>{
    expect(parseHash('#/unknown')).toEqual({kind:'home'});
    expect(parseHash('#/category')).toEqual({kind:'home'});
    expect(parseHash('#/exam/id/abc')).toEqual({kind:'home'});
    expect(parseHash('')).toEqual({kind:'home'});
  });
  it('decodes uri components',()=>{
    expect(parseHash('#/category/%D8%AC')).toEqual({kind:'category',ref:'ج'});
    expect(parseHash('#/exam/%D8%A7%D9%85%D8%AA%D8%AD%D8%A7%D9%86/2')).toEqual({kind:'exam',examId:'امتحان',version:2});
  });
  it('renders hashes from routes',()=>{
    expect(toHash({kind:'home'})).toBe('#/');
    expect(toHash({kind:'categories'})).toBe('#/categories');
    expect(toHash({kind:'category',ref:'xxx'})).toBe('#/category/xxx');
    expect(toHash({kind:'exam',examId:'id',version:1})).toBe('#/exam/id/1');
    expect(toHash({kind:'result'})).toBe('#/result');
  });
  it('round-trips a fixed set',()=>{
    const hashes=['#/','#/categories','#/category/%D8%AC','#/exam/id/1','#/result'];
    for(const h of hashes)expect(toHash(parseHash(h))).toBe(h);
  });
});