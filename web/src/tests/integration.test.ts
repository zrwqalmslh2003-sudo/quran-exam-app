// @vitest-environment node
import {afterEach,beforeEach,describe,expect,it,vi} from 'vitest';
import {ContentRepository} from '../content/repository';
import {resolveCategoryTree,scoreQuestion} from '../domain/content';
import {clearSession,loadSession,saveSession} from '../storage/session';
import {loadLastResult,saveResult} from '../storage/results';

class MemoryStorage { private values=new Map<string,string>(); getItem(k:string){return this.values.get(k)??null;} setItem(k:string,v:string){this.values.set(k,v);} removeItem(k:string){this.values.delete(k);} clear(){this.values.clear();} }
const manifest={schemaVersion:1,contentVersion:2,exams:[{id:'vertical_exam',version:1,title:'اختبار الشريحة',file:'exams/vertical_exam.json',category:'quran',questionCount:2,sha256:'x'}]};
const exam={schemaVersion:1,id:'vertical_exam',version:1,title:'اختبار الشريحة',category:'quran',questions:[{id:'q1',type:'single_choice',prompt:'السؤال الأول',options:['صحيح','خطأ'],correctAnswer:0},{id:'q2',type:'single_choice',prompt:'السؤال الثاني',options:['أ','ب'],correctAnswer:1}]};

beforeEach(()=>{Object.assign(globalThis,{localStorage:new MemoryStorage()});vi.stubGlobal('fetch',vi.fn(async(url:string)=>({ok:true,status:200,json:async()=>url.endsWith('manifest.json')?manifest:exam})));});
afterEach(()=>{vi.unstubAllGlobals();});

describe('Web-1 vertical slice',()=>{it('loads, answers, scores, saves result and session',async()=>{const repo=new ContentRepository('https://content.test');const loaded=await repo.fetchManifest();const tree=resolveCategoryTree(loaded.exams);const entry=tree[0].exams[0];const loadedExam=await repo.fetchExam(entry);const answers:Record<string,number>={q1:0,q2:0};const score=loadedExam.questions.reduce((n,q)=>n+(scoreQuestion(q,answers[q.id])?1:0),0);saveResult({id:'result-1',userId:'u',examId:entry.id,examTitle:entry.title,version:entry.version,startedAt:'s',finishedAt:'f',score,total:loadedExam.questions.length,errors:loadedExam.questions.filter(q=>!scoreQuestion(q,answers[q.id])).map(q=>({questionId:q.id,prompt:q.prompt,submitted:answers[q.id],correct:typeof q.correctAnswer==='number'?q.correctAnswer:-1}))});expect(loadLastResult()?.score).toBe(1);expect(loadLastResult()?.errors).toHaveLength(1);expect(loadLastResult()?.errors[0].correct).toBe(1);saveSession({userId:'u',examId:entry.id,version:entry.version,index:1,answers,startedAt:'s'});expect(loadSession()?.index).toBe(1);clearSession();expect(loadSession()).toBeNull();});});
