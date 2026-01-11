//
//  AddressSearchView.swift
//  TrackRide
//
//  Apple Maps address search using MKLocalSearchCompleter
//

import SwiftUI
import MapKit

/// Result from address search containing the formatted address and optional coordinates
struct AddressSearchResult {
    let address: String
    let latitude: Double?
    let longitude: Double?
}

/// Observable wrapper for MKLocalSearchCompleter
@Observable
final class AddressSearchCompleter: NSObject, MKLocalSearchCompleterDelegate {
    var searchText: String = "" {
        didSet {
            completer.queryFragment = searchText
        }
    }

    var results: [MKLocalSearchCompletion] = []
    var isSearching: Bool = false

    private let completer: MKLocalSearchCompleter

    override init() {
        completer = MKLocalSearchCompleter()
        completer.resultTypes = [.address, .pointOfInterest]
        super.init()
        completer.delegate = self
    }

    // MARK: - MKLocalSearchCompleterDelegate

    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        Task { @MainActor in
            self.results = completer.results
            self.isSearching = false
        }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        Task { @MainActor in
            self.isSearching = false
        }
    }

    /// Get the full address and coordinates for a search completion
    func getDetails(for completion: MKLocalSearchCompletion) async -> AddressSearchResult? {
        let request = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: request)

        do {
            let response = try await search.start()
            if let item = response.mapItems.first {
                let address = formatAddress(from: item)
                return AddressSearchResult(
                    address: address,
                    latitude: item.placemark.coordinate.latitude,
                    longitude: item.placemark.coordinate.longitude
                )
            }
        } catch {
            // Fall back to just the completion text without coordinates
        }

        // Fallback: return the completion title without coordinates
        let address = [completion.title, completion.subtitle]
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
        return AddressSearchResult(address: address, latitude: nil, longitude: nil)
    }

    private func formatAddress(from mapItem: MKMapItem) -> String {
        var components: [String] = []

        if let name = mapItem.name, !name.isEmpty {
            components.append(name)
        }

        if let placemark = mapItem.placemark as MKPlacemark? {
            // Add street address if different from name
            if let thoroughfare = placemark.thoroughfare {
                let streetAddress = [placemark.subThoroughfare, thoroughfare]
                    .compactMap { $0 }
                    .joined(separator: " ")
                if !streetAddress.isEmpty && streetAddress != mapItem.name {
                    components.append(streetAddress)
                }
            }

            // Add locality
            if let locality = placemark.locality {
                components.append(locality)
            }

            // Add postal code
            if let postalCode = placemark.postalCode {
                components.append(postalCode)
            }
        }

        return components.joined(separator: ", ")
    }
}

/// View for searching and selecting an address
struct AddressSearchView: View {
    @Environment(\.dismiss) private var dismiss

    let onSelect: (AddressSearchResult) -> Void

    @State private var completer = AddressSearchCompleter()
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            List {
                if completer.searchText.isEmpty {
                    ContentUnavailableView(
                        "Search for a venue",
                        systemImage: "mappin.and.ellipse",
                        description: Text("Enter an address, venue name, or postcode")
                    )
                } else if completer.results.isEmpty && !completer.isSearching {
                    ContentUnavailableView(
                        "No results",
                        systemImage: "magnifyingglass",
                        description: Text("Try a different search term")
                    )
                } else {
                    ForEach(completer.results, id: \.self) { result in
                        Button {
                            selectResult(result)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(result.title)
                                    .font(.body)
                                    .foregroundStyle(.primary)

                                if !result.subtitle.isEmpty {
                                    Text(result.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .searchable(text: $completer.searchText, prompt: "Search address or venue")
            .navigationTitle("Find Venue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .overlay {
                if isLoading {
                    ProgressView("Getting address...")
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    private func selectResult(_ completion: MKLocalSearchCompletion) {
        isLoading = true

        Task {
            if let result = await completer.getDetails(for: completion) {
                await MainActor.run {
                    isLoading = false
                    onSelect(result)
                    dismiss()
                }
            } else {
                await MainActor.run {
                    isLoading = false
                }
            }
        }
    }
}

#Preview {
    AddressSearchView { result in
        print("Selected: \(result.address)")
    }
}
