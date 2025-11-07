//
//  HomeView.swift
//  Athena
//
//  Created by Cursor
//

import SwiftUI
import EventKit

struct HomeView: View {
    @EnvironmentObject var appViewModel: AppViewModel
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppMetrics.spacingLarge) {
                // Greeting Section
                greetingSection
                
                // Today's Calendar Events
                calendarSection
                
                // Recent Notes
                recentNotesSection
            }
            .padding(AppMetrics.paddingLarge)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppMaterial.primaryGlass)
        .onAppear {
            // Ensure events are fetched when the view appears
            Task {
                await appViewModel.dayViewModel.fetchEvents()
            }
        }
    }
    
    // MARK: - Greeting Section
    
    private var greetingSection: some View {
        GlassCard(
            material: AppMaterial.tertiaryGlass,
            cornerRadius: AppMetrics.cornerRadiusLarge,
            padding: AppMetrics.paddingLarge
        ) {
            VStack(alignment: .leading, spacing: AppMetrics.spacingSmall) {
                Text("Hello, I'm Athena.")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.primary)
                
                Text("Your intelligent assistant")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    // MARK: - Calendar Section
    
    private var calendarSection: some View {
        GlassCard(
            material: AppMaterial.secondaryGlass,
            cornerRadius: AppMetrics.cornerRadiusLarge,
            padding: AppMetrics.padding
        ) {
            VStack(alignment: .leading, spacing: AppMetrics.spacingMedium) {
                HStack {
                    HStack(spacing: AppMetrics.spacingSmall) {
                        Image(systemName: "calendar")
                            .font(.system(size: AppMetrics.iconSize, weight: .semibold))
                            .foregroundStyle(.primary)
                        
                        Text("Today's Events")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.primary)
                    }
                    
                    Spacer()
                    
                    GlassButton(
                        title: "View All",
                        systemImage: "chevron.right",
                        action: { appViewModel.showCalendar() },
                        style: .secondary,
                        size: .small
                    )
                }
                
                if appViewModel.dayViewModel.isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppMetrics.paddingMedium)
                } else if let errorMessage = appViewModel.dayViewModel.errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(AppColors.error)
                        .padding(.vertical, AppMetrics.paddingSmall)
                } else if todayEvents.isEmpty {
                    Text("No events scheduled for today")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .padding(.vertical, AppMetrics.paddingMedium)
                } else {
                    VStack(spacing: AppMetrics.spacingSmall) {
                        ForEach(todayEvents.prefix(5)) { event in
                            EventSummaryRow(event: event)
                        }
                        
                        if todayEvents.count > 5 {
                            GlassButton(
                                title: "+ \(todayEvents.count - 5) more events",
                                systemImage: nil,
                                action: { appViewModel.showCalendar() },
                                style: .secondary,
                                size: .small
                            )
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Recent Notes Section
    
    private var recentNotesSection: some View {
        GlassCard(
            material: AppMaterial.secondaryGlass,
            cornerRadius: AppMetrics.cornerRadiusLarge,
            padding: AppMetrics.padding
        ) {
            VStack(alignment: .leading, spacing: AppMetrics.spacingMedium) {
                HStack {
                    HStack(spacing: AppMetrics.spacingSmall) {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: AppMetrics.iconSize, weight: .semibold))
                            .foregroundStyle(.primary)
                        
                        Text("Recent Notes")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.primary)
                    }
                    
                    Spacer()
                    
                    GlassButton(
                        title: "View All",
                        systemImage: "chevron.right",
                        action: { appViewModel.showNotes() },
                        style: .secondary,
                        size: .small
                    )
                }
                
                if recentNotes.isEmpty {
                    Text("No notes yet")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .padding(.vertical, AppMetrics.paddingMedium)
                } else {
                    VStack(spacing: AppMetrics.spacingSmall) {
                        ForEach(recentNotes) { note in
                            NoteSummaryRow(note: note)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var todayEvents: [CalendarEvent] {
        // Get events from DayViewModel (which is already configured for today by default)
        appViewModel.dayViewModel.events
    }
    
    private var recentNotes: [NoteModel] {
        // Get the last 2 most recently modified notes
        Array(appViewModel.notesViewModel.notes
            .sorted(by: { $0.modifiedAt > $1.modifiedAt })
            .prefix(2))
    }
}

// MARK: - Event Summary Row

struct EventSummaryRow: View {
    let event: CalendarEvent
    @State private var isHovering = false
    
    var body: some View {
        HStack(spacing: AppMetrics.spacingMedium) {
            // Calendar color indicator
            RoundedRectangle(cornerRadius: AppMetrics.cornerRadiusXSmall, style: .continuous)
                .fill(Color(event.calendar.cgColor))
                .frame(width: 4)
            
            VStack(alignment: .leading, spacing: AppMetrics.spacingXSmall) {
                Text(event.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                
                HStack(spacing: AppMetrics.spacingSmall) {
                    if event.isAllDay {
                        Label("All Day", systemImage: "clock")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    } else {
                        Label(formatEventTime(event), systemImage: "clock")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    
                    if let location = event.location, !location.isEmpty {
                        Label(location, systemImage: "location.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            
            Spacer()
        }
        .padding(.vertical, AppMetrics.spacingSmall)
        .padding(.horizontal, AppMetrics.spacingMedium)
        .background(
            RoundedRectangle(cornerRadius: AppMetrics.cornerRadiusSmall, style: .continuous)
                .fill(Color(event.calendar.cgColor).opacity(isHovering ? 0.15 : 0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppMetrics.cornerRadiusSmall, style: .continuous)
                .strokeBorder(
                    Color(event.calendar.cgColor).opacity(isHovering ? 0.4 : 0.25),
                    lineWidth: 1
                )
        )
        .scaleEffect(isHovering ? 1.01 : 1.0)
        .onHover { hovering in
            withAnimation(AppAnimations.springEasing) {
                isHovering = hovering
            }
        }
    }
    
    private func formatEventTime(_ event: CalendarEvent) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        
        let startTime = formatter.string(from: event.startDate)
        let endTime = formatter.string(from: event.endDate)
        
        return "\(startTime) - \(endTime)"
    }
}

// MARK: - Note Summary Row

struct NoteSummaryRow: View {
    let note: NoteModel
    @State private var isHovering = false
    
    var body: some View {
        Button(action: {}) {
            VStack(alignment: .leading, spacing: AppMetrics.spacingSmall) {
                HStack {
                    Text(note.title.isEmpty ? "Untitled" : note.title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .opacity(isHovering ? 1.0 : 0.0)
                }
                
                if !note.body.isEmpty {
                    Text(note.body)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .truncationMode(.tail)
                }
                
                HStack {
                    Image(systemName: "clock")
                        .font(.system(size: 10))
                    Text(formatNoteDate(note.modifiedAt))
                        .font(.system(size: 11))
                }
                .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(AppMetrics.paddingMedium)
            .background(
                RoundedRectangle(cornerRadius: AppMetrics.cornerRadiusSmall, style: .continuous)
                    .fill(isHovering ? AppColors.hoverOverlay : AppColors.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppMetrics.cornerRadiusSmall, style: .continuous)
                    .strokeBorder(
                        isHovering ? AppColors.accent.opacity(0.3) : AppColors.border,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovering ? 1.01 : 1.0)
        .onHover { hovering in
            withAnimation(AppAnimations.springEasing) {
                isHovering = hovering
            }
        }
    }
    
    private func formatNoteDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Preview

#Preview {
    HomeView()
        .environmentObject(AppViewModel())
        .frame(width: 800, height: 600)
}

