"use client";

import { useRouter } from "next/navigation";
import { useEffect } from "react";
import {
    CommandDialog,
    CommandEmpty,
    CommandGroup,
    CommandInput,
    CommandItem,
    CommandList,
    CommandSeparator,
} from "@/components/ui/command";
import {
    Map,
    Ticket,
    Package,
    Box,
    Settings,
    Building2,
    Plus,
} from "lucide-react";

interface CommandPaletteProps {
    open: boolean;
    onOpenChange: (open: boolean) => void;
}

export function CommandPalette({ open, onOpenChange }: CommandPaletteProps) {
    const router = useRouter();

    // Handle keyboard shortcut
    useEffect(() => {
        const down = (e: KeyboardEvent) => {
            if (e.key === "k" && (e.metaKey || e.ctrlKey)) {
                e.preventDefault();
                onOpenChange(!open);
            }
        };

        document.addEventListener("keydown", down);
        return () => document.removeEventListener("keydown", down);
    }, [open, onOpenChange]);

    const runCommand = (command: () => void) => {
        onOpenChange(false);
        command();
    };

    return (
        <CommandDialog open={open} onOpenChange={onOpenChange}>
            <CommandInput placeholder="Type a command or search..." />
            <CommandList>
                <CommandEmpty>No results found.</CommandEmpty>

                <CommandGroup heading="Navigation">
                    <CommandItem onSelect={() => runCommand(() => router.push("/app/map"))}>
                        <Map className="mr-2 h-4 w-4" />
                        <span>Go to Map</span>
                    </CommandItem>
                    <CommandItem
                        onSelect={() => runCommand(() => router.push("/app/tickets"))}
                    >
                        <Ticket className="mr-2 h-4 w-4" />
                        <span>Go to Tickets</span>
                    </CommandItem>
                    <CommandItem
                        onSelect={() => runCommand(() => router.push("/app/bundles"))}
                    >
                        <Box className="mr-2 h-4 w-4" />
                        <span>Go to Bundles</span>
                    </CommandItem>
                    <CommandItem
                        onSelect={() => runCommand(() => router.push("/app/packages"))}
                    >
                        <Package className="mr-2 h-4 w-4" />
                        <span>Go to Packages</span>
                    </CommandItem>
                    <CommandItem
                        onSelect={() => runCommand(() => router.push("/app/settings"))}
                    >
                        <Settings className="mr-2 h-4 w-4" />
                        <span>Go to Settings</span>
                    </CommandItem>
                </CommandGroup>

                <CommandSeparator />

                <CommandGroup heading="Quick Actions">
                    <CommandItem
                        onSelect={() => runCommand(() => router.push("/app/property/new"))}
                    >
                        <Building2 className="mr-2 h-4 w-4" />
                        <span>Add Property</span>
                    </CommandItem>
                    <CommandItem
                        onSelect={() => runCommand(() => router.push("/app/tickets/new"))}
                    >
                        <Plus className="mr-2 h-4 w-4" />
                        <span>Create Ticket</span>
                    </CommandItem>
                </CommandGroup>
            </CommandList>
        </CommandDialog>
    );
}
