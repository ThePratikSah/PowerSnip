import SwiftUI

/// Modal sheet or banner presenting the Screen Recording permission prompt on first launch or when permission is missing.
struct ScreenRecordingPermissionSheet: View {
    @Bindable var permissionManager = ScreenCapturePermissionManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.12))
                    .frame(width: 64, height: 64)

                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 30))
                    .foregroundStyle(Color.accentColor)
            }
            .padding(.top, 8)

            // Titles
            VStack(spacing: 6) {
                Text("Screen Recording Permission Required")
                    .font(.headline)
                    .multilineTextAlignment(.center)

                Text("Snip requires Screen Recording permission to capture sections of your screen and extract text or analyze images. macOS requires this for all screenshot and recording tools.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 16)

            // Status indication
            HStack(spacing: 8) {
                Image(systemName: permissionManager.isGranted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(permissionManager.isGranted ? .green : .orange)
                Text(permissionManager.isGranted ? "Permission Granted" : "Permission not yet granted in System Settings")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(permissionManager.isGranted ? .green : .secondary)
            }
            .padding(.vertical, 4)

            Divider()

            // Action Buttons
            VStack(spacing: 10) {
                Button(action: {
                    permissionManager.requestPermission()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "gearshape")
                        Text("Open System Settings")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                HStack(spacing: 12) {
                    Button("Dismiss") {
                        permissionManager.showPermissionPrompt = false
                        dismiss()
                    }
                    .keyboardShortcut(.cancelAction)

                    Spacer()

                    Button("Check Again") {
                        if permissionManager.checkPermission() {
                            dismiss()
                        }
                    }
                }
            }
            .padding(.horizontal, 8)
        }
        .padding(24)
        .frame(width: 440)
        .onAppear {
            permissionManager.checkPermission()
            permissionManager.startPolling()
        }
        .onDisappear {
            if permissionManager.isGranted {
                permissionManager.stopPolling()
            }
        }
    }
}
