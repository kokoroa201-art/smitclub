import type { Metadata } from "next";
import { Geist, Geist_Mono } from "next/font/google";
import Link from "next/link";
import "./globals.css";
import { getCurrentProfile } from "@/lib/auth";
import { signOut } from "@/lib/actions/auth";

const geistSans = Geist({
  variable: "--font-geist-sans",
  subsets: ["latin"],
});

const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin"],
});

export const metadata: Metadata = {
  title: "SMIT CLUB",
  description: "SMIT 대학원 동아리 포털",
};

export default async function RootLayout({ children }: LayoutProps<"/">) {
  const profile = await getCurrentProfile();

  return (
    <html
      lang="ko"
      className={`${geistSans.variable} ${geistMono.variable} h-full antialiased`}
    >
      <body className="min-h-full flex flex-col">
        <header className="flex items-center justify-between border-b border-neutral-200 px-4 py-3">
          <Link href="/" className="font-bold">
            SMIT CLUB
          </Link>
          {profile ? (
            <div className="flex items-center gap-3 text-sm">
              <span className="text-neutral-600">
                {profile.name}님 ({profile.role})
              </span>
              <form action={signOut}>
                <button type="submit" className="text-orange-600 underline">
                  로그아웃
                </button>
              </form>
            </div>
          ) : (
            <div className="flex items-center gap-3 text-sm">
              <Link href="/login" className="text-neutral-600">
                로그인
              </Link>
              <Link href="/signup" className="text-orange-600 underline">
                회원가입
              </Link>
            </div>
          )}
        </header>
        {children}
      </body>
    </html>
  );
}
