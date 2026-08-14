import Link from "next/link";
import { signIn } from "@/lib/actions/auth";

export default async function LoginPage(props: PageProps<"/login">) {
  const params = await props.searchParams;
  const error = typeof params.error === "string" ? params.error : null;

  return (
    <main className="mx-auto flex min-h-[70vh] w-full max-w-sm flex-col justify-center gap-6 px-4 py-12">
      <div>
        <h1 className="text-2xl font-bold">로그인</h1>
        <p className="mt-1 text-sm text-neutral-500">SMIT CLUB에 오신 것을 환영해요.</p>
      </div>

      {error && (
        <p className="rounded-md bg-red-50 px-3 py-2 text-sm text-red-600">{error}</p>
      )}

      <form action={signIn} className="flex flex-col gap-4">
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
            className="rounded-md border border-neutral-300 px-3 py-2"
          />
        </label>
        <button
          type="submit"
          className="rounded-md bg-orange-500 px-4 py-2 font-medium text-white hover:bg-orange-600"
        >
          로그인
        </button>
      </form>

      <p className="text-sm text-neutral-500">
        계정이 없으신가요?{" "}
        <Link href="/signup" className="text-orange-600 underline">
          회원가입
        </Link>
      </p>
    </main>
  );
}
