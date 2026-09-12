import {act,cleanup,render,screen} from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import {afterEach,beforeEach,describe,expect,it,vi} from 'vitest';
import App from '../App';

const manifest={schemaVersion:1,contentVersion:2,exams:[{id:'vertical_exam',version:1,title:'اختبار الشريحة',file:'exams/vertical_exam.json',category:'quran',questionCount:2,sha256:'x'}]};
const exam={schemaVersion:1,id:'vertical_exam',version:1,title:'اختبار الشريحة',category:'quran',questions:[{id:'q1',type:'single_choice',prompt:'السؤال الأول',options:['نعم','لا'],correctAnswer:0,explanation:'المرجع: الآية الأولى'},{id:'q2',type:'single_choice',prompt:'السؤال الثاني',options:['أربعة','خمسة'],correctAnswer:1}]};

function stubOkFetch(){vi.stubGlobal('fetch',vi.fn(async(url:string)=>({ok:true,status:200,json:async()=>String(url).endsWith('manifest.json')?manifest:exam})));}

beforeEach(()=>{localStorage.clear();window.location.hash='#/';});
afterEach(()=>{cleanup();vi.unstubAllGlobals();});

describe('App',()=>{
  it('shows loading first then home after initial fetch',async()=>{
    let resolveFetch!:()=>void;
    const fetchMock=vi.fn((url:string)=>new Promise((resolve)=>{resolveFetch=()=>resolve({ok:true,status:200,json:async()=>String(url).endsWith('manifest.json')?manifest:exam});}));
    vi.stubGlobal('fetch',fetchMock as unknown as typeof fetch);
    render(<App/>);
    expect(screen.getByText(/جاري تحميل المحتوى/)).toBeInTheDocument();
    await act(async()=>{resolveFetch();await Promise.resolve();});
    expect(await screen.findByRole('button',{name:/استكشف الاختبارات/})).toBeInTheDocument();
  });

  it('shows notice with retry when fetch fails',async()=>{
    vi.stubGlobal('fetch',vi.fn().mockRejectedValue(new Error('network down')));
    render(<App/>);
    expect(await screen.findByRole('button',{name:'إعادة المحاولة'})).toBeInTheDocument();
    expect(screen.getByText('network down')).toBeInTheDocument();
  });

  it('navigates home to categories to category to exam',async()=>{
    stubOkFetch();
    const user=userEvent.setup();
    render(<App/>);
    await user.click(await screen.findByRole('button',{name:/استكشف الاختبارات/}));
    expect(screen.getByText('اختر مجالاً للبدء')).toBeInTheDocument();
    await user.click(screen.getByRole('button',{name:/quran/}));
    expect(await screen.findByText('الاختبارات المتاحة')).toBeInTheDocument();
    await user.click(screen.getByRole('button',{name:/اختبار الشريحة/}));
    expect(await screen.findByText('السؤال الأول')).toBeInTheDocument();
  });

  it('answers one right and one wrong then shows score 1 of 2',async()=>{
    stubOkFetch();
    const user=userEvent.setup();
    render(<App/>);
    await user.click(await screen.findByRole('button',{name:/استكشف الاختبارات/}));
    await user.click(screen.getByRole('button',{name:/quran/}));
    await user.click(await screen.findByRole('button',{name:/اختبار الشريحة/}));
    await screen.findByText('السؤال الأول');
    await user.click(screen.getByRole('radio',{name:/نعم/}));
    await user.click(screen.getByRole('button',{name:/متابعة/}));
    await screen.findByText('السؤال الثاني');
    await user.click(screen.getByRole('radio',{name:/أربعة/}));
    await user.click(screen.getByRole('button',{name:/إنهاء الاختبار/}));
    expect(await screen.findByText('نتيجتك النهائية')).toBeInTheDocument();
    expect(screen.getByText('1')).toBeInTheDocument();
    expect(screen.getByText('/ 2')).toBeInTheDocument();
  });

  it('shows exam as unavailable when a question type is unsupported',async()=>{
    const unsupportedInterview={...exam,questions:exam.questions.map(q=>q.id==='q2'?{...q,type:'ayah'}:q)};
    vi.stubGlobal('fetch',vi.fn(async(url:string)=>({ok:true,status:200,json:async()=>String(url).endsWith('manifest.json')?manifest:unsupportedInterview})));
    const user=userEvent.setup();
    render(<App/>);
    await user.click(await screen.findByRole('button',{name:/استكشف الاختبارات/}));
    await user.click(screen.getByRole('button',{name:/quran/}));
    await user.click(await screen.findByRole('button',{name:/اختبار الشريحة/}));
    expect(await screen.findByText('هذا الاختبار يحتوي نوع سؤال غير مدعوم في هذه النسخة')).toBeInTheDocument();
  });

  it('reviews the last saved result with the correct field',async()=>{
    stubOkFetch();
    const saved={id:'r1',userId:'u',examId:'vertical_exam',examTitle:'اختبار الشريحة',version:1,startedAt:'s',finishedAt:'f',score:1,total:2,errors:[{questionId:'q1',prompt:'السؤال الأول',submitted:1,correct:0}]};
    localStorage.setItem('qalon.result.last',JSON.stringify(saved));
    window.location.hash='#/result';
    render(<App/>);
    expect(await screen.findByText('مراجعة آخر نتيجة')).toBeInTheDocument();
    expect(screen.getByText('السؤال الأول')).toBeInTheDocument();
    expect(screen.getByText('الإجابة الصحيحة: الخيار 1')).toBeInTheDocument();
  });

  it('shows correct feedback and turns the next button into continue',async()=>{
    stubOkFetch();
    const user=userEvent.setup();
    render(<App/>);
    await user.click(await screen.findByRole('button',{name:/استكشف الاختبارات/}));
    await user.click(screen.getByRole('button',{name:/quran/}));
    await user.click(await screen.findByRole('button',{name:/اختبار الشريحة/}));
    await screen.findByText('السؤال الأول');
    await user.click(screen.getByRole('radio',{name:/نعم/}));
    expect(await screen.findByText('✅ إجابة صحيحة')).toBeInTheDocument();
    expect(screen.getByRole('button',{name:/متابعة/})).toBeInTheDocument();
    expect(screen.getByRole('radio',{name:/نعم/})).toBeDisabled();
  });

  it('shows wrong feedback, highlights the correct option and shows the explanation',async()=>{
    stubOkFetch();
    const user=userEvent.setup();
    render(<App/>);
    await user.click(await screen.findByRole('button',{name:/استكشف الاختبارات/}));
    await user.click(screen.getByRole('button',{name:/quran/}));
    await user.click(await screen.findByRole('button',{name:/اختبار الشريحة/}));
    await screen.findByText('السؤال الأول');
    await user.click(screen.getByRole('radio',{name:/لا/}));
    expect(await screen.findByText('❌ إجابة خاطئة')).toBeInTheDocument();
    expect(screen.getByRole('radio',{name:/نعم/})).toHaveClass('correct');
    expect(screen.getByRole('radio',{name:/لا/})).toHaveClass('wrong');
    expect(screen.getByText('المرجع: الآية الأولى')).toBeInTheDocument();
  });
});