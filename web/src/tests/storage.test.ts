import {beforeEach,describe,expect,it} from 'vitest';
import {getUserId} from '../storage/user';
import {clearSession,loadSession,saveSession} from '../storage/session';
import {loadLastResult,saveResult} from '../storage/results';

class MemoryStorage { private values=new Map<string,string>(); getItem(k:string){return this.values.get(k)??null;} setItem(k:string,v:string){this.values.set(k,v);} removeItem(k:string){this.values.delete(k);} clear(){this.values.clear();} }

beforeEach(()=>{Object.assign(globalThis,{localStorage:new MemoryStorage()});});

describe('browser storage',()=>{
  it('creates one user id and reuses it',()=>{const first=getUserId();expect(first).toBeTruthy();expect(getUserId()).toBe(first);});
  it('saves, loads and clears a session',()=>{const session={userId:'u',examId:'e',version:1,index:2,answers:{q1:1},startedAt:'2026-01-01'};saveSession(session);expect(loadSession()).toEqual(session);clearSession();expect(loadSession()).toBeNull();});
  it('returns null for corrupt session JSON',()=>{localStorage.setItem('qalon.session.active','{bad');expect(loadSession()).toBeNull();});
  it('replaces the previous result',()=>{const first={id:'1',userId:'u',examId:'a',examTitle:'أ',version:1,startedAt:'s',finishedAt:'f',score:1,total:2,errors:[]};const second={...first,id:'2',examId:'b',score:2};saveResult(first);saveResult(second);expect(loadLastResult()).toEqual(second);});
  it('returns null when there is no result',()=>{expect(loadLastResult()).toBeNull();});
});
