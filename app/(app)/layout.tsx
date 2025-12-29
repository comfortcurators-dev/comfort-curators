import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { AppShell } from "@/components/app-shell";

interface OrgMembership {
    org_id: string;
    orgs: { id: string; name: string } | null;
}

export default async function AppLayout({
    children,
}: {
    children: React.ReactNode;
}) {
    const supabase = await createClient();

    const {
        data: { user },
    } = await supabase.auth.getUser();

    if (!user) {
        redirect("/login");
    }

    // Fetch user's organizations with explicit typing
    const { data: memberships } = await supabase
        .from("org_members")
        .select("org_id, orgs(id, name)")
        .eq("user_id", user.id)
        .eq("status", "active");

    // Fetch user profile with proper typing
    const { data: profileData } = await supabase
        .from("profiles")
        .select("full_name")
        .eq("user_id", user.id)
        .single();

    const profile = profileData as { full_name: string | null } | null;

    // Transform memberships to org list with proper typing
    const orgs = (memberships as unknown as OrgMembership[] | null)
        ?.filter((m) => m.orgs !== null)
        .map((m) => ({
            id: m.orgs!.id,
            name: m.orgs!.name,
        })) || [];

    return (
        <AppShell
            user={{
                email: user.email || "",
                full_name: profile?.full_name || undefined,
            }}
            orgs={orgs}
            currentOrgId={orgs[0]?.id}
        >
            {children}
        </AppShell>
    );
}
