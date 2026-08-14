import { cookies } from "next/headers";
import { createClient } from "@/utils/supabase/server";

export type Role = "student" | "club_admin" | "super_admin";

export type Profile = {
  id: string;
  name: string;
  student_id: string | null;
  affiliation: string | null;
  role: Role;
  locale_pref: "ko" | "en";
  created_at: string;
};

export async function getCurrentProfile(): Promise<Profile | null> {
  const cookieStore = await cookies();
  const supabase = createClient(cookieStore);

  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) return null;

  const { data: profile } = await supabase
    .from("profiles")
    .select("*")
    .eq("id", user.id)
    .single();

  return (profile as Profile | null) ?? null;
}
