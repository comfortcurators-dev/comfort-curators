import type { Metadata } from "next";

export const metadata: Metadata = {
    title: "Log in",
    description: "Sign in to your Comfort Curators account",
};

export default function AuthLayout({
    children,
}: {
    children: React.ReactNode;
}) {
    return (
        <div className="min-h-screen flex">
            {/* Left side - Form */}
            <div className="flex-1 flex items-center justify-center px-8">
                <div className="w-full max-w-sm">{children}</div>
            </div>

            {/* Right side - Branding (hidden on mobile) */}
            <div className="hidden lg:flex flex-1 bg-muted items-center justify-center p-12">
                <div className="max-w-md text-center">
                    <div className="mb-8">
                        <div className="w-16 h-16 mx-auto rounded-2xl bg-primary/10 flex items-center justify-center">
                            <span className="text-3xl font-bold text-primary">CC</span>
                        </div>
                    </div>
                    <h2 className="text-2xl font-semibold mb-4">
                        Manage properties with confidence
                    </h2>
                    <p className="text-muted-foreground">
                        Join thousands of property managers across India who use Comfort
                        Curators to streamline their operations.
                    </p>
                </div>
            </div>
        </div>
    );
}
