"use client";

import { useState } from "react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { cn } from "@/lib/utils";
import { Button } from "@/components/ui/button";
import { ThemeToggle } from "@/components/theme-toggle";
import {
    Sidebar,
    SidebarContent,
    SidebarFooter,
    SidebarGroup,
    SidebarGroupContent,
    SidebarGroupLabel,
    SidebarHeader,
    SidebarMenu,
    SidebarMenuButton,
    SidebarMenuItem,
    SidebarProvider,
    SidebarTrigger,
} from "@/components/ui/sidebar";
import {
    DropdownMenu,
    DropdownMenuContent,
    DropdownMenuItem,
    DropdownMenuLabel,
    DropdownMenuSeparator,
    DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { Avatar, AvatarFallback } from "@/components/ui/avatar";
import {
    Building2,
    Map,
    Ticket,
    Package,
    Box,
    Settings,
    LogOut,
    ChevronDown,
    Search,
} from "lucide-react";
import { createClient } from "@/lib/supabase/client";
import { useRouter } from "next/navigation";
import { CommandPalette } from "@/components/command-palette";

const menuItems = [
    { title: "Map", icon: Map, href: "/app/map" },
    { title: "Tickets", icon: Ticket, href: "/app/tickets" },
    { title: "Bundles", icon: Box, href: "/app/bundles" },
    { title: "Packages", icon: Package, href: "/app/packages" },
    { title: "Settings", icon: Settings, href: "/app/settings" },
];

interface AppShellProps {
    children: React.ReactNode;
    user: { email: string; full_name?: string } | null;
    orgs: { id: string; name: string }[];
    currentOrgId?: string;
}

export function AppShell({
    children,
    user,
    orgs,
    currentOrgId,
}: AppShellProps) {
    const router = useRouter();
    const pathname = usePathname();
    const [commandOpen, setCommandOpen] = useState(false);

    const currentOrg = orgs.find((o) => o.id === currentOrgId) || orgs[0];
    const userInitials =
        user?.full_name
            ?.split(" ")
            .map((n) => n[0])
            .join("")
            .toUpperCase() || user?.email?.[0]?.toUpperCase() || "U";

    const handleLogout = async () => {
        const supabase = createClient();
        await supabase.auth.signOut();
        router.push("/login");
        router.refresh();
    };

    return (
        <SidebarProvider>
            <div className="flex min-h-screen w-full">
                <Sidebar className="border-r">
                    <SidebarHeader className="p-4">
                        <div className="flex items-center gap-2">
                            <Building2 className="h-6 w-6 text-primary" />
                            <span className="font-semibold">Comfort Curators</span>
                        </div>

                        {/* Organization Switcher */}
                        {orgs.length > 0 && (
                            <DropdownMenu>
                                <DropdownMenuTrigger asChild>
                                    <Button
                                        variant="ghost"
                                        className="w-full justify-between mt-2"
                                    >
                                        <span className="truncate">{currentOrg?.name}</span>
                                        <ChevronDown className="h-4 w-4 opacity-50" />
                                    </Button>
                                </DropdownMenuTrigger>
                                <DropdownMenuContent className="w-56">
                                    <DropdownMenuLabel>Organizations</DropdownMenuLabel>
                                    <DropdownMenuSeparator />
                                    {orgs.map((org) => (
                                        <DropdownMenuItem
                                            key={org.id}
                                            onClick={() =>
                                                router.push(`/app?org=${org.id}`)
                                            }
                                        >
                                            {org.name}
                                        </DropdownMenuItem>
                                    ))}
                                </DropdownMenuContent>
                            </DropdownMenu>
                        )}
                    </SidebarHeader>

                    <SidebarContent>
                        <SidebarGroup>
                            <SidebarGroupLabel>Navigation</SidebarGroupLabel>
                            <SidebarGroupContent>
                                <SidebarMenu>
                                    {menuItems.map((item) => (
                                        <SidebarMenuItem key={item.href}>
                                            <SidebarMenuButton
                                                asChild
                                                isActive={pathname === item.href}
                                            >
                                                <Link href={item.href}>
                                                    <item.icon className="h-4 w-4" />
                                                    <span>{item.title}</span>
                                                </Link>
                                            </SidebarMenuButton>
                                        </SidebarMenuItem>
                                    ))}
                                </SidebarMenu>
                            </SidebarGroupContent>
                        </SidebarGroup>
                    </SidebarContent>

                    <SidebarFooter className="p-4">
                        <DropdownMenu>
                            <DropdownMenuTrigger asChild>
                                <Button
                                    variant="ghost"
                                    className="w-full justify-start gap-2"
                                >
                                    <Avatar className="h-6 w-6">
                                        <AvatarFallback className="text-xs">
                                            {userInitials}
                                        </AvatarFallback>
                                    </Avatar>
                                    <span className="truncate text-sm">
                                        {user?.full_name || user?.email}
                                    </span>
                                </Button>
                            </DropdownMenuTrigger>
                            <DropdownMenuContent align="end" className="w-56">
                                <DropdownMenuLabel>
                                    {user?.full_name || "Account"}
                                </DropdownMenuLabel>
                                <DropdownMenuSeparator />
                                <DropdownMenuItem asChild>
                                    <Link href="/app/settings">
                                        <Settings className="mr-2 h-4 w-4" />
                                        Settings
                                    </Link>
                                </DropdownMenuItem>
                                <DropdownMenuSeparator />
                                <DropdownMenuItem onClick={handleLogout}>
                                    <LogOut className="mr-2 h-4 w-4" />
                                    Log out
                                </DropdownMenuItem>
                            </DropdownMenuContent>
                        </DropdownMenu>
                    </SidebarFooter>
                </Sidebar>

                {/* Main content */}
                <div className="flex-1 flex flex-col min-w-0">
                    {/* Top bar */}
                    <header className="h-14 border-b flex items-center px-4 gap-4 bg-background">
                        <SidebarTrigger />
                        <Button
                            variant="outline"
                            className="flex-1 max-w-sm justify-start text-muted-foreground"
                            onClick={() => setCommandOpen(true)}
                        >
                            <Search className="mr-2 h-4 w-4" />
                            <span className="hidden sm:inline">Search...</span>
                            <kbd className="ml-auto hidden sm:inline-flex pointer-events-none h-5 select-none items-center gap-1 rounded border bg-muted px-1.5 font-mono text-xs font-medium">
                                ⌘K
                            </kbd>
                        </Button>
                        <ThemeToggle />
                    </header>

                    {/* Page content */}
                    <main className="flex-1 overflow-auto">{children}</main>
                </div>
            </div>

            <CommandPalette open={commandOpen} onOpenChange={setCommandOpen} />
        </SidebarProvider>
    );
}
