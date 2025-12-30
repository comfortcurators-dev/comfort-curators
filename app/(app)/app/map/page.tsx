"use client";

import { useEffect, useRef, useState } from "react";
import maplibregl from "maplibre-gl";
import "maplibre-gl/dist/maplibre-gl.css";
import { Button } from "@/components/ui/button";
import {
    Sheet,
    SheetContent,
    SheetDescription,
    SheetHeader,
    SheetTitle,
} from "@/components/ui/sheet";
import { Plus, Locate } from "lucide-react";

export default function MapPage() {
    const mapContainer = useRef<HTMLDivElement>(null);
    const map = useRef<maplibregl.Map | null>(null);
    const [selectedProperty, setSelectedProperty] = useState<{
        id: string;
        name: string;
        address: string;
    } | null>(null);
    const [isAddingProperty, setIsAddingProperty] = useState(false);

    useEffect(() => {
        if (map.current || !mapContainer.current) return;

        const tileUrl = process.env.NEXT_PUBLIC_MAP_TILE_URL_TEMPLATE || "https://tile.openstreetmap.org/{z}/{x}/{y}.png";
        const attribution = process.env.NEXT_PUBLIC_MAP_ATTRIBUTION || "© OpenStreetMap contributors";

        // Initialize map centered on India
        map.current = new maplibregl.Map({
            container: mapContainer.current,
            style: {
                version: 8,
                sources: {
                    "raster-tiles": {
                        type: "raster",
                        tiles: [tileUrl],
                        tileSize: 256,
                        attribution: attribution,
                    },
                },
                layers: [
                    {
                        id: "simple-tiles",
                        type: "raster",
                        source: "raster-tiles",
                        minzoom: 0,
                        maxzoom: 22,
                    },
                ],
            },
            center: [78.9629, 20.5937], // Center of India
            zoom: 5,
        });

        // Add navigation controls
        map.current.addControl(new maplibregl.NavigationControl(), "top-right");

        // Handle click for adding property
        map.current.on("click", (e) => {
            if (isAddingProperty) {
                console.log("Add property at:", e.lngLat);
                // TODO: Open property creation dialog with coordinates
                setIsAddingProperty(false);
            }
        });

        return () => {
            map.current?.remove();
        };
    }, [isAddingProperty]);

    const handleLocateUser = () => {
        if (navigator.geolocation) {
            navigator.geolocation.getCurrentPosition(
                (position) => {
                    map.current?.flyTo({
                        center: [position.coords.longitude, position.coords.latitude],
                        zoom: 14,
                    });
                },
                (error) => {
                    console.error("Error getting location:", error);
                }
            );
        }
    };

    return (
        <div className="h-full relative">
            {/* Map */}
            <div ref={mapContainer} className="absolute inset-0 map-container" />

            {/* Floating controls */}
            <div className="absolute top-4 left-4 flex flex-col gap-2 z-10">
                <Button
                    size="sm"
                    variant={isAddingProperty ? "default" : "secondary"}
                    onClick={() => setIsAddingProperty(!isAddingProperty)}
                    className="shadow-lg"
                >
                    <Plus className="h-4 w-4 mr-2" />
                    {isAddingProperty ? "Click map to add" : "Add Property"}
                </Button>
                <Button
                    size="icon"
                    variant="secondary"
                    onClick={handleLocateUser}
                    className="shadow-lg"
                >
                    <Locate className="h-4 w-4" />
                </Button>
            </div>

            {/* Empty state message */}
            <div className="absolute bottom-8 left-1/2 -translate-x-1/2 z-10">
                <div className="bg-background/90 backdrop-blur-sm rounded-lg px-6 py-4 shadow-lg border text-center">
                    <p className="text-muted-foreground text-sm mb-2">
                        No properties yet
                    </p>
                    <Button
                        size="sm"
                        onClick={() => setIsAddingProperty(true)}
                    >
                        <Plus className="h-4 w-4 mr-2" />
                        Add your first property
                    </Button>
                </div>
            </div>

            {/* Property detail sheet */}
            <Sheet
                open={!!selectedProperty}
                onOpenChange={() => setSelectedProperty(null)}
            >
                <SheetContent className="property-sheet">
                    <SheetHeader>
                        <SheetTitle>{selectedProperty?.name}</SheetTitle>
                        <SheetDescription>{selectedProperty?.address}</SheetDescription>
                    </SheetHeader>
                    {/* Property details will go here */}
                </SheetContent>
            </Sheet>
        </div>
    );
}
