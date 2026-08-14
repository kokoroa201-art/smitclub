import Link from "next/link";
import { signUp } from "@/lib/actions/auth";

export default async function SignupPage(props: PageProps<"/signup">) {
  const params = await props.searchParams;
  const error = typeof params.error === "string" ? params.error : null;

  return (
    <main className="mx-auto flex min-h-[70vh] w-full max-w-sm flex-col justify-center gap-6 px-4 py-12">
      <div>
        <h1 className="text-2xl font-bold">회원가입</h1>
        <p className="mt-1 text-sm text-neutral-500">
          이름, 학번, 소속만 알려주시면 바로 시작할 수 있어요.
        </p>
      </div>

      {error && (
        <p className="rounded-md bg-red-50 px-3 py-2 text-sm text-red-600">{error}</p>
      )}

      <form action={signUp} className="flex flex-col gap-4">
        <label className="flex flex-col gap-1 text-sm">
          이름
          <input
            type="text"
            name="name"
            required
            className="rounded-md border border-neutral-300 px-3 py-2"
          />
        </label>
        <label className="flex flex-col gap-1 text-sm">
          학번
          <input
            type="text"
            name="student_id"
            className="rounded-md border border-neutral-300 px-3 py-2"
          />
        </label>
        <label className="flex flex-col gap-1 text-sm">
          소속
          <input
            type="text"
            name="affiliation"
            placeholder="예: 글로벌미디어학과"
            className="rounded-md border border-neutral-300 px-3 py-2"
          />
        </label>
        <label className="flex flex-col gap-1 text-sm">
          이메일
          <input
            type="email"
            name="email"
            required
            className="rounded-md border border-neutral-300 px-3 py-2"
          />
        </label>
        <label className="flex flex-col gap-1 text-sm">
          비밀번호
          <input
            type="password"
            name="password"
            required
            minLength={6}
            className="rounded-md border border-neutral-300 px-3 py-2"
          />
        </label>
        <button
          type="submit"
          className="rounded-md bg-orange-500 px-4 py-2 font-medium text-white hover:bg-orange-600"
        >
          가입하기
        </button>
      </form>

      <p className="text-sm text-neutral-500">
        이미 계정이 있으신가요?{" "}
        <Link href="/login" className="text-orange-600 underline">
          로그인
        </Link>
      </p>
    </main>
  );
}
