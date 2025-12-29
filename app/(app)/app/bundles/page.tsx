import { Box } from "lucide-react";

export default function BundlesPage() {
    return (
        <div className="p-6">
            <div className="flex items-center justify-between mb-6">
                <div>
                    <h1 className="text-2xl font-semibold tracking-tight">Bundles</h1>
                    <p className="text-muted-foreground">
                        Create reusable item bundles for your properties
                    </p>
                </div>
            </div>

            {/* Empty state */}
            <div className="flex flex-col items-center justify-center py-20 border rounded-lg border-dashed">
                <Box className="h-12 w-12 text-muted-foreground/50 mb-4" />
                <p className="text-muted-foreground mb-2">No bundles yet</p>
                <p className="text-sm text-muted-foreground/70">
                    Create bundles to group items for quick assignment to tickets
                </p>
            </div>
        </div>
    );
}
