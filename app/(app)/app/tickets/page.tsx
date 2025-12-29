import { Ticket } from "lucide-react";

export default function TicketsPage() {
    return (
        <div className="p-6">
            <div className="flex items-center justify-between mb-6">
                <div>
                    <h1 className="text-2xl font-semibold tracking-tight">Tickets</h1>
                    <p className="text-muted-foreground">
                        Manage and track work across your properties
                    </p>
                </div>
            </div>

            {/* Empty state */}
            <div className="flex flex-col items-center justify-center py-20 border rounded-lg border-dashed">
                <Ticket className="h-12 w-12 text-muted-foreground/50 mb-4" />
                <p className="text-muted-foreground mb-2">No tickets yet</p>
                <p className="text-sm text-muted-foreground/70">
                    Tickets will be generated automatically from packages or created manually
                </p>
            </div>
        </div>
    );
}
