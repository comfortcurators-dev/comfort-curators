import { Package } from "lucide-react";

export default function PackagesPage() {
    return (
        <div className="p-6">
            <div className="flex items-center justify-between mb-6">
                <div>
                    <h1 className="text-2xl font-semibold tracking-tight">Packages</h1>
                    <p className="text-muted-foreground">
                        Create scheduled packages that auto-generate tickets
                    </p>
                </div>
            </div>

            {/* Empty state */}
            <div className="flex flex-col items-center justify-center py-20 border rounded-lg border-dashed">
                <Package className="h-12 w-12 text-muted-foreground/50 mb-4" />
                <p className="text-muted-foreground mb-2">No packages yet</p>
                <p className="text-sm text-muted-foreground/70">
                    Packages automate ticket creation based on bookings or schedules
                </p>
            </div>
        </div>
    );
}
