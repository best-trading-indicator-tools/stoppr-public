# ─────────────────────────  Global settings ─────────────────────────
platform :ios, '15.0'                     # WidgetKit ≥ iOS 15
ENV['COCOAPODS_DISABLE_STATS'] = 'true'

project 'Runner',
        'Debug'   => :debug,
        'Profile' => :release,
        'Release' => :release

# ─────────────────────────  Flutter helper  ─────────────────────────
def flutter_root
  gen = File.expand_path(File.join('..', 'Flutter', 'Generated.xcconfig'), __FILE__)
  raise "#{gen} missing; run `flutter pub get`" unless File.exist?(gen)

  File.foreach(gen) { |l| return $1.strip if l =~ /FLUTTER_ROOT=(.*)/ }
  raise 'FLUTTER_ROOT not found in Generated.xcconfig'
end

require File.expand_path(
  File.join('packages', 'flutter_tools', 'bin', 'podhelper'),
  flutter_root
)
flutter_ios_podfile_setup

# ─────────────────────────  CocoaPods flags  ────────────────────────
use_frameworks! :linkage => :static
use_modular_headers!

# ─────────────────────────  Targets  ────────────────────────────────
target 'Runner' do
  flutter_install_all_ios_pods(File.dirname(File.realpath(__FILE__)))

  target 'RunnerTests' do
    inherit! :search_paths
  end

  # Le widget *n’embarque aucun pod* ; il hérite juste des search-paths.
  target 'StreakWidgetExtension' do
    inherit! :search_paths
  end
end

# ─────────────────────────  Post-install  ───────────────────────────
post_install do |installer|
  # 1️⃣  Supprimer l’agrégateur Pods-StreakWidgetExtension (inutile)
  installer.pods_project.targets
          .select { |t| t.name == 'Pods-StreakWidgetExtension' }
          .each   { |t| t.remove_from_project }
  installer.pods_project.save

  # 2️⃣  Appliquer les réglages Flutter + forcer iOS 15 partout
  installer.pods_project.targets.each do |t|
    flutter_additional_ios_build_settings(t)
    t.build_configurations.each do |cfg|
      cfg.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
    end
  end

  # 3️⃣  Nettoyer le xcodeproj utilisateur (widget + app)
  require 'xcodeproj'
  user_proj = Xcodeproj::Project.open(File.join(__dir__, 'Runner.xcodeproj'))

  # ——— Widget ————————————————————————————————
  widget = user_proj.targets.find { |t| t.name == 'StreakWidgetExtension' }
  if widget
    # • virer le framework fantôme
    widget.frameworks_build_phase.files
          .select { |f| f.display_name == 'Pods_StreakWidgetExtension.framework' }
          .each(&:remove_from_project)

    # • virer tous les build-phases [CP] (dont « Check Pods Manifest.lock »)
    widget.build_phases
          .select { |bp| bp.respond_to?(:name) && bp.name&.start_with?('[CP]') }
          .each  { |bp| widget.build_phases.delete(bp) }

    # • enlever la base-config Pods* et rétablir les warnings hérités
    widget.build_configurations.each do |cfg|
      cfg.base_configuration_reference = nil
      cfg.build_settings['CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER'] = '$(inherited)'
    end
  end

  # ——— App principale Runner ————————————————
  runner = user_proj.targets.find { |t| t.name == 'Runner' }
  if runner
    # • forcer iOS 15
    runner.build_configurations.each do |cfg|
      cfg.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
    end

    # • supprimer tout Copy-Files redondant qui embarque 2× l’appex
    #runner.build_phases
    #      .select { |bp| bp.isa == 'PBXCopyFilesBuildPhase' &&
    #                     bp.files_references.any? { |f| f.path&.end_with?('StreakWidgetExtension.appex') } }
    #       .each(&:remove_from_project)
  end

  user_proj.save
end
