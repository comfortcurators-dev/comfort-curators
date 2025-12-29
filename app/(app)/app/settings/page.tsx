import { Settings } from "lucide-react";

export default function SettingsPage() {
    return (
        <div className="p-6">
            <div className="flex items-center justify-between mb-6">
                <div>
                    <h1 className="text-2xl font-semibold tracking-tight">Settings</h1>
                    <p className="text-muted-foreground">
                        Manage your organization settings and preferences
                    </p>
                </div>
            </div>

            <div className="space-y-6 max-w-2xl">
                <div className="notion-card p-6">
                    <h2 className="font-medium mb-4">Organization</h2>
                    <p className="text-sm text-muted-foreground">
                        Organization settings will be available here once the database is set up.
                    </p>
                </div>

                <div className="notion-card p-6">
                    <h2 className="font-medium mb-4">Billing</h2>
                    <p className="text-sm text-muted-foreground">
                        Subscription and billing settings coming soon.
                    </p>
                </div>

                <div className="notion-card p-6">
                    <h2 className="font-medium mb-4">Compliance</h2>
                    <p className="text-sm text-muted-foreground">
                        DSAR requests and consent management.
                    </p>
                </div>
            </div>
        </div>
    );
}
