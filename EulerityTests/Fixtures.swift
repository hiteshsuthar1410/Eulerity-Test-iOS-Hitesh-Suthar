//
//  Fixtures.swift
//  EulerityTests
//
//  Shared JSON fixtures for the parsing/mapping test suites.
//

import Foundation

enum Fixtures {
    /// The canonical sample payload from the brief.
    static let fullSample = """
    {
      "theme": {
        "background_color": "#FFFFFF",
        "text_color": "#111827",
        "border_color": "#D1D5DB",
        "error_color": "#B91C1C"
      },
      "form_title": "Campaign Setup",
      "fields": [
        {
          "id": "campaign_name",
          "order": 1,
          "type": "TEXT",
          "subtype": "PLAIN",
          "label": "Campaign Name",
          "placeholder": "e.g., Summer Sale",
          "max_length": 30,
          "error_message": "Name is required.",
          "required": true
        },
        {
          "id": "ad_networks",
          "order": 2,
          "type": "DROPDOWN",
          "label": "Ad Networks",
          "allow_multiple": true,
          "default_values": ["net_meta"],
          "required": true,
          "options": [
            { "id": "net_google", "label": "Google Search" },
            { "id": "net_meta", "label": "Meta Platforms" }
          ]
        },
        {
          "id": "daily_budget",
          "order": 3,
          "type": "TEXT",
          "subtype": "NUMBER",
          "label": "Daily Budget ($)",
          "required": true
        },
        {
          "id": "accept_legal",
          "order": 4,
          "type": "CHECKBOX",
          "label": "I agree to the Terms of Service.",
          "required": true,
          "metadata": {
            "Terms of Service": "https://example.com/terms"
          },
          "clickable_text_color": "#2563EB"
        }
      ]
    }
    """
}
