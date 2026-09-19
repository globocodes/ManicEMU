//
//  SpecialCoreOption.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/8/14.
//  Copyright © 2026 Manic EMU. All rights reserved.
//

enum SpecialCoreOption: String {
    //psp
    case ppsspp_enable_wlan
    case ppsspp_enable_builtin_pro_ad_hoc_server
    case ppsspp_change_pro_ad_hoc_server_address
    case ppsspp_pro_ad_hoc_server_address01
    case ppsspp_pro_ad_hoc_server_address02
    case ppsspp_pro_ad_hoc_server_address03
    case ppsspp_pro_ad_hoc_server_address04
    case ppsspp_pro_ad_hoc_server_address05
    case ppsspp_pro_ad_hoc_server_address06
    case ppsspp_pro_ad_hoc_server_address07
    case ppsspp_pro_ad_hoc_server_address08
    case ppsspp_pro_ad_hoc_server_address09
    case ppsspp_pro_ad_hoc_server_address10
    case ppsspp_pro_ad_hoc_server_address11
    case ppsspp_pro_ad_hoc_server_address12
    case ppsspp_port_offset
    case ppsspp_language
    case ppsspp_backend
    case ppsspp_texture_replacement
    case ppsspp_cpu_core
    case ppsspp_internal_resolution
    case ppsspp_cheats
    //nes fds
    case nestopia_palette
    case nestopia_aspect
    //isPicodriveCore
    case picodrive_input1
    case picodrive_input2
    //snes
    case bsnes_ppu_no_vram_blocking
    case snes9x_block_invalid_vram_access
    //ClownMDEmuCore
    case clownmdemu_tv_standard
    //ss
    case yabause_addon_cartridge
    case beetle_saturn_region
    case beetle_saturn_cart
    case beetle_saturn_horizontal_overscan
    //ds
    //melonDS
    case melonds_firmware_language
    case melonds_console_mode
    case melonds_mic_input
    case melonds_jit_enable
    case melonds_mic_input_active
    case melonds_hybrid_ratio
    case melonds_hybrid_small_screen
    case melonds_number_of_screen_layouts
    case melonds_screen_gap
    case melonds_screen_layout1
    case melonds_screen_layout2
    case melonds_screen_layout3
    case melonds_screen_layout4
    case melonds_screen_layout5
    case melonds_screen_layout6
    case melonds_screen_layout7
    case melonds_screen_layout8
    case melonds_custom_layout_config
    case melonds_show_cursor
    //desmume
    case desmume_internal_resolution
    case desmume_firmware_language
    case desmume_mic_mode
    case desmume_pointer_type
    case desmume_pointer_device_l
    case desmume_pointer_device_r
    case desmume_screens_layout
    case desmume_screens_gap
    case desmume_hybrid_layout_ratio
    case desmume_hybrid_layout_scale
    case desmume_hybrid_showboth_screens
    case desmume_hybrid_cursor_always_smallscreen
    //gba gbc gb
    case vbam_gbHardware
    case vbam_usebios
    //gbc
    case gambatte_gbc_color_correction
    //gb
    case gambatte_gb_colorization
    case gambatte_gb_internal_palette
    case mgba_gb_colors
    case vbam_palettes
    //n64
    case mupen64plus_cpucore = "mupen64plus-cpucore"
    case mupen64plus_rdp_plugin = "mupen64plus-rdp-plugin"
    case mupen64plus_pak1 = "mupen64plus-pak1"
    case mupen64plus_parallel_rdp_upscaling = "mupen64plus-parallel-rdp-upscaling"
    case mupen64plus_43screensize = "mupen64plus-43screensize"
    //vb
    case vb_color_mode
    //pm
    case pokemini_palette
    //ps1
    case beetle_psx_hw_internal_resolution
    case beetle_psx_hw_override_bios
    case beetle_psx_hw_renderer
    case beetle_psx_hw_cpu_dynarec
    case beetle_psx_hw_dither_mode
    case beetle_psx_hw_msaa
    case beetle_psx_hw_mdec_yuv
    case beetle_psx_hw_aspect_ratio
    case beetle_psx_hw_enable_memcard1
    case beetle_psx_hw_pgxp_mode
    case beetle_psx_hw_pgxp_nclip
    case beetle_psx_hw_pgxp_texture
    case beetle_psx_hw_gte_overclock
    case pcsx_rearmed_analog_combo
    //dc
    case reicast_internal_resolution
    case reicast_language
    case reicast_renderer
    //arcade
    case mame_cheats_enable
    //isAzahar3DS
    case citra_use_cpu_jit
    case citra_use_default_aes_key
    case citra_required_online_lle_modules
    case citra_touch_touchscreen
    case citra_input_type
    case citra_layout_option
    case citra_swap_screen
    case citra_swap_screen_mode
    case citra_large_screen_proportion
    case citra_custom_layout_config
    case citra_motion_rotation
    //a2600
    case stella_crop_hoverscan
    //a5200
    case atari800_system
    //jaguar
    case virtualjaguar_alt_inputs
    case virtualjaguar_bios
    case virtualjaguar_doom_res_hack
    case virtualjaguar_p1_retropad_analog_lu
    case virtualjaguar_p1_retropad_analog_ld
    case virtualjaguar_p1_retropad_analog_ll
    case virtualjaguar_p1_retropad_analog_lr
    case virtualjaguar_p1_retropad_analog_ru
    case virtualjaguar_p2_retropad_analog_lu
    case irtualjaguar_p2_retropad_analog_ld
    case virtualjaguar_p2_retropad_analog_ll
    case virtualjaguar_p2_retropad_analog_lr
    case virtualjaguar_p2_retropad_analog_ru
    //doom
    case prboom_resolution = "prboom-resolution"
    case prboom_rumble = "prboom-rumble"
    //dos
    case dosbox_pure_cpu_core
    //symbian
    case eka2l1_cpu_backend
    case screen_buffer_sync
    case eka2l1_device_index
    //dolphin
    case dolphin_cpu_clock_rate
    case dolphin_cpu_core
    case dolphin_osd_enabled
    case dolphin_fast_disc_speed
    case dolphin_gpu_texture_decoding
    case dolphin_shader_compilation_mode
    case dolphin_log_level
    case dolphin_log_boot
    case dolphin_log_core
    case dolphin_log_video
    case dolphin_log_common
    case dolphin_vi_skip
    case dolphin_skip_gc_bios
    case dolphin_fastmem_arena
    case dolphin_cheats_enabled
    case dolphin_cheats_import
    //gamecube
    case dolphin_gc_sp1
    case dolphin_enable_gamecube_mic
    case dolphin_hotkey_activate_microphone
    //wii
    case dolphin_widescreen
    case dolphin_progressive_scan
    case dolphin_pal60
    case dolphin_sensor_bar_position
    case dolphin_enable_rumble
    case dolphin_wiimote_continuous_scanning
    case dolphin_alt_gc_ports_on_wii
    case dolphin_wiispeak_enable
    case dolphin_wiispeak_muted
    case dolphin_wii_logi_microphone_enable
    case dolphin_bluetooth_passthrough
    
    //pce
    case pce_default_joypad_type_p1
    case pce_default_joypad_type_p2
    case pce_default_joypad_type_p3
    case pce_default_joypad_type_p4
    case pce_default_joypad_type_p5
    
    
    
    func isOptimizationCoreConfig(key: String,
                                  game: Game) -> Bool {
        guard let config = SpecialCoreOption(rawValue: key) else { return false }
        return Self.getOptimizationCoreOptions(game: game).contains(config)
    }
    
    ///Some core configurations already have convenient setup entries in the frontend.
    ///Get the list of these optimized core settings.
    ///PS. User cannot see these options in the core settings.
    static func getOptimizationCoreOptions(game: Game) -> Set<Self> {
        if game.gameType == .psp {
            return [
                .ppsspp_enable_wlan,
                .ppsspp_enable_builtin_pro_ad_hoc_server,
                .ppsspp_change_pro_ad_hoc_server_address,
                .ppsspp_pro_ad_hoc_server_address01,
                .ppsspp_pro_ad_hoc_server_address02,
                .ppsspp_pro_ad_hoc_server_address03,
                .ppsspp_pro_ad_hoc_server_address04,
                .ppsspp_pro_ad_hoc_server_address05,
                .ppsspp_pro_ad_hoc_server_address06,
                .ppsspp_pro_ad_hoc_server_address07,
                .ppsspp_pro_ad_hoc_server_address08,
                .ppsspp_pro_ad_hoc_server_address09,
                .ppsspp_pro_ad_hoc_server_address10,
                .ppsspp_pro_ad_hoc_server_address11,
                .ppsspp_pro_ad_hoc_server_address12,
                .ppsspp_port_offset,
                .ppsspp_language,
                .ppsspp_backend,
                .ppsspp_texture_replacement,
                .ppsspp_cpu_core,
                .ppsspp_internal_resolution
            ]
        } else if game.gameType == .nes || game.gameType == .fds {
            return [.nestopia_palette]
        } else if game.gameType == .snes {
            if game.defaultCore == 0 {
                return [.bsnes_ppu_no_vram_blocking]
            } else if game.defaultCore == 1 {
                return [.snes9x_block_invalid_vram_access]
            }
        } else if game.isClownMDEmuCore {
            return [.clownmdemu_tv_standard]
        } else if game.gameType == .ss {
            if game.defaultCore == 0 {
                return [.beetle_saturn_region]
            }
        } else if game.gameType == .ds {
            if game.defaultCore == 0 {
                return [
                    .melonds_firmware_language,
                    .melonds_console_mode,
                    .melonds_mic_input,
                    .melonds_jit_enable,
                    .melonds_hybrid_ratio,
                    .melonds_hybrid_small_screen,
                    .melonds_number_of_screen_layouts,
                    .melonds_screen_gap,
                    .melonds_screen_layout1,
                    .melonds_screen_layout2,
                    .melonds_screen_layout3,
                    .melonds_screen_layout4,
                    .melonds_screen_layout5,
                    .melonds_screen_layout6,
                    .melonds_screen_layout7,
                    .melonds_screen_layout8,
                    .melonds_custom_layout_config,
                ]
            } else if game.defaultCore == 1 {
                return [
                    .desmume_internal_resolution,
                    .desmume_firmware_language,
                    .desmume_mic_mode,
                    .desmume_screens_layout,
                    .desmume_screens_gap,
                    .desmume_hybrid_layout_ratio,
                    .desmume_hybrid_layout_scale,
                    .desmume_hybrid_showboth_screens,
                    .desmume_hybrid_cursor_always_smallscreen,
                ]
            }
        } else if game.gameType == .gba {
            if game.defaultCore == 1 {
                return [.vbam_gbHardware]
            }
        } else if game.gameType == .gbc {
            if game.defaultCore == 2 {
                return [.vbam_gbHardware]
            }
        } else if game.gameType == .gb {
            if game.defaultCore == 0 {
                return [
                    .gambatte_gb_colorization,
                    .gambatte_gb_internal_palette
                ]
            } else if game.defaultCore == 1 {
                return [.mgba_gb_colors]
            } else if game.defaultCore == 2 {
                return [
                    .vbam_gbHardware,
                    .vbam_palettes
                ]
            }
            
        } else if game.gameType == .n64 {
            return [
                .mupen64plus_cpucore,
                .mupen64plus_rdp_plugin,
                .mupen64plus_pak1,
                .mupen64plus_parallel_rdp_upscaling,
                .mupen64plus_43screensize
            ]
        } else if game.gameType == .vb {
            return [.vb_color_mode]
        } else if game.gameType == .pm {
            return [.pokemini_palette]
        } else if game.gameType == .ps1 {
            if game.defaultCore == 0 {
                return [
                    .beetle_psx_hw_internal_resolution,
                    .beetle_psx_hw_override_bios,
                    .beetle_psx_hw_renderer,
                    .beetle_psx_hw_cpu_dynarec,
                ]
            } else if game.defaultCore == 1 {
                return [.pcsx_rearmed_analog_combo]
            }
        } else if game.gameType == .dc {
            return [
                .reicast_internal_resolution,
                .reicast_language
            ]
        } else if game.isAzahar3DS {
            return [
                .citra_use_cpu_jit,
                .citra_use_default_aes_key,
                .citra_layout_option,
                .citra_layout_option,
                .citra_swap_screen,
                .citra_swap_screen_mode,
                .citra_large_screen_proportion,
                .citra_custom_layout_config,
                .citra_motion_rotation,
            ]
        } else if game.gameType == .doom {
            return [.prboom_resolution]
        } else if game.gameType == .dos {
            return [.dosbox_pure_cpu_core]
        } else if game.gameType == .symbian {
            return [.eka2l1_cpu_backend,
                    .eka2l1_device_index]
        } else if game.isDolphinCore {
            var result: [SpecialCoreOption] = [.dolphin_cheats_enabled,
                                               .dolphin_cheats_import,
                                               .dolphin_cpu_core,
                                               .dolphin_skip_gc_bios]
            if game.gameType == .wii {
                result += [.dolphin_gc_sp1,
                           .dolphin_enable_gamecube_mic,
                           .dolphin_hotkey_activate_microphone]
            } else if game.gameType == .ngc {
                result += [.dolphin_widescreen,
                           .dolphin_progressive_scan,
                           .dolphin_pal60,
                           .dolphin_sensor_bar_position,
                           .dolphin_enable_rumble,
                           .dolphin_wiimote_continuous_scanning,
                           .dolphin_alt_gc_ports_on_wii,
                           .dolphin_wiispeak_enable,
                           .dolphin_wiispeak_muted,
                           .dolphin_wii_logi_microphone_enable,
                           .dolphin_bluetooth_passthrough]
            }
            return Set(result)
            
        } else if game.gameType == .pce {
            return [.pce_default_joypad_type_p1,
                    .pce_default_joypad_type_p2,
                    .pce_default_joypad_type_p3,
                    .pce_default_joypad_type_p4,
                    .pce_default_joypad_type_p5]
        }
        return []
    }
    
    ///Tested optimal core settings, but may be overwritten by user attempts to adjust core settings.
    static func getBestSetupCoreConfigs(game: Game) -> [String: String] {
        var result: [Self: String] = [:]
        if game.gameType == .psp {
            result = [.ppsspp_cheats: "enabled"]
        } else if game.gameType == .nes || game.gameType == .fds {
            result = [.nestopia_aspect: "uncorrected"]
        } else if game.isPicodriveCore {
            result = [
                .picodrive_input1: "6 button pad",
                .picodrive_input2: "6 button pad"
            ]
        } else if game.gameType == .ss {
            if game.defaultCore == 0 {
                result = [.yabause_addon_cartridge: "4M_ram"]
            } else if game.defaultCore == 1 {
                result = [
                    .beetle_saturn_cart: "Extended RAM (4MB)",
                    .beetle_saturn_horizontal_overscan: "20"
                ]
            }
        } else if game.gameType == .ds {
            result = [
                .melonds_mic_input_active: "always",
                .melonds_number_of_screen_layouts: "1",
                .melonds_screen_layout1: "custom",
                .melonds_show_cursor: "disabled",
                .desmume_pointer_type: "touch",
                .desmume_pointer_device_l: "emulated",
                .desmume_pointer_device_r: "emulated",
            ]
        } else if game.gameType == .gba {
            result = [.vbam_usebios: "enabled"]
        } else if game.gameType == .gbc {
            result = [
                .gambatte_gbc_color_correction: "disabled",
                .vbam_usebios: "enabled"
            ]
        } else if game.gameType == .gb {
            result = [.vbam_usebios: "enabled"]
        } else if game.gameType == .ps1, game.defaultCore == 0 {
            result = [
                .beetle_psx_hw_dither_mode: "disabled",
                .beetle_psx_hw_msaa: "8x",
                .beetle_psx_hw_mdec_yuv: "enabled",
                .beetle_psx_hw_aspect_ratio: "4:3",
                //memory card
                .beetle_psx_hw_enable_memcard1: "disabled",
                //pgxp
                .beetle_psx_hw_pgxp_mode: "memory only",
                .beetle_psx_hw_pgxp_nclip: "enabled",
                .beetle_psx_hw_pgxp_texture: "enabled",
                //hacks
                .beetle_psx_hw_gte_overclock: "enabled",
            ]
        } else if game.gameType == .dc {
            result = [.reicast_renderer: "Vulkan"]
        } else if game.gameType == .arcade, game.defaultCore == 0 {
            result = [.mame_cheats_enable: "enabled"]
        } else if game.isAzahar3DS {
            result = [
                .citra_layout_option: "custom",
                .citra_touch_touchscreen: "enabled",
                .citra_input_type: "frontend",
            ]
        } else if game.gameType == .a2600 {
            result = [.stella_crop_hoverscan: "enabled"]
        } else if game.gameType == .a5200 {
            result = [.atari800_system: "5200"]
        } else if game.gameType == .jaguar {
            result = [.virtualjaguar_alt_inputs: "enabled",
                      .virtualjaguar_bios: "enabled",
                      .virtualjaguar_doom_res_hack: "enabled",
                      .virtualjaguar_p1_retropad_analog_lu: "num_7",
                      .virtualjaguar_p1_retropad_analog_ld: "num_8",
                      .virtualjaguar_p1_retropad_analog_ll: "num_9",
                      .virtualjaguar_p1_retropad_analog_lr: "star",
                      .virtualjaguar_p1_retropad_analog_ru: "hash",
                      .virtualjaguar_p2_retropad_analog_lu: "num_7",
                      .irtualjaguar_p2_retropad_analog_ld: "num_8",
                      .virtualjaguar_p2_retropad_analog_ll: "num_9",
                      .virtualjaguar_p2_retropad_analog_lr: "star",
                      .virtualjaguar_p2_retropad_analog_ru: "hash"
            ]
        } else if game.gameType == .doom {
            result = [.prboom_rumble: "enabled"]
        } else if game.gameType == .symbian {
            result = [.screen_buffer_sync: "off"]
        } else if game.isDolphinCore {
            let enableJIT = LibretroCore.jitAvailable() && game.jit
            if enableJIT {
                result = [
                    .dolphin_cpu_clock_rate: "1.00",
                    .dolphin_osd_enabled: "disabled",
                    .dolphin_fast_disc_speed: "disabled",
                    .dolphin_gpu_texture_decoding: "disabled",
                    .dolphin_shader_compilation_mode: "0",
                    .dolphin_log_level: "1",
                    .dolphin_log_boot: "disabled",
                    .dolphin_log_core: "disabled",
                    .dolphin_log_video: "disabled",
                    .dolphin_log_common: "disabled",
                    .dolphin_vi_skip: "disabled",
                    .dolphin_skip_gc_bios: "disabled",
                ]
#if NO_EXTENDED_VA
                /// Manic MP: a personal team is refused Extended Virtual Addressing
                /// (BP-I20), and JitArm64's fastmem arena reserves 12 GiB of address
                /// space. Without the entitlement that reservation can fail with a
                /// panic alert at boot, so JIT sessions start without the arena:
                /// slower memory access, still JIT. A paid-program build clears
                /// APP_EXTENDED_VA_CONDITION (Config-Local.xcconfig.example) and gets
                /// the arena back. It stays an ordinary per-game core option, so the
                /// arena can be tried by hand on a personal-team build.
                result[.dolphin_fastmem_arena] = "disabled"
#endif
            } else {
                let enableManicInterpreter = game.getExtraBool(key: ExtraKey.dolphinManicInterpreter.rawValue) ?? true
                var clockRate: String
                switch UIDevice.performanceTier {
                case .high:
                    clockRate = enableManicInterpreter ? "0.40" : "0.30"
                case .ultra:
                    clockRate = enableManicInterpreter ? "0.70" : "0.50"
                default:
                    clockRate = "0.20"
                }
                /// Manic MP: the underclock keeps the interpreter at full emulator
                /// speed by giving the game a slower CPU. A title with a variable
                /// timestep hides that: speed and audio read 100% while the game
                /// itself drops from 30 fps to 20 or 15 and input lag grows
                /// (docs/chibi-robo-performance-investigation-2026-09-19.md). Those
                /// titles run the full clock instead; a stored per-game value still wins.
                if let gameID = game.gameIDForDolphin, dolphinFullClockGameIDs.contains(gameID) {
                    clockRate = "1.00"
                }
                result = [
                    .dolphin_cpu_clock_rate: clockRate,
                    .dolphin_osd_enabled: "disabled",
                    .dolphin_fast_disc_speed: "enabled",
                    .dolphin_gpu_texture_decoding: "enabled",
                    .dolphin_shader_compilation_mode: "3",
                    .dolphin_log_level: "1",
                    .dolphin_log_boot: "disabled",
                    .dolphin_log_core: "disabled",
                    .dolphin_log_video: "disabled",
                    .dolphin_log_common: "disabled",
                    .dolphin_vi_skip: "enabled",
                    .dolphin_skip_gc_bios: "disabled",
                ]
            }
        } else if game.gameType == .pce {
            result = [
                .pce_default_joypad_type_p1: "6 Buttons",
                .pce_default_joypad_type_p2: "6 Buttons",
                .pce_default_joypad_type_p3: "6 Buttons",
                .pce_default_joypad_type_p4: "6 Buttons",
                .pce_default_joypad_type_p5: "6 Buttons"
            ]
        }
        return result.mapKeysAndValues({ ($0.key.rawValue, $0.value) })
    }
    
    /// Manic MP: GameCube titles that cannot absorb the no-JIT underclock, by disc
    /// id. Chibi-Robo! (USA, Europe, Japan) caps itself at 30 fps, measures how many
    /// video interrupts each frame took and advances its logic by that much.
    static let dolphinFullClockGameIDs: Set<String> = ["GGTE01", "GGTP01", "GGTJ01"]

    /// Manic MP: how a Dolphin session is about to run, from the options it will
    /// actually get (best setup, then the play screen's, then the stored per-game
    /// ones). The emulator's own speed readout cannot tell an interpreter session
    /// on an underclocked CPU from a JIT session, so the app says it outright.
    /// `compact` is what the game info screen keeps; `full` goes to the toast and
    /// the session log.
    static func dolphinRunMode(resolvedCoreConfigs configs: [String: String]) -> (compact: String, full: String) {
        let coreName: String
        switch configs[Self.dolphin_cpu_core.rawValue] {
        case "4": coreName = "JITARM64"
        case "5": coreName = "Cached Interpreter"
        case "6": coreName = "Manic Interpreter"
        case let other?: coreName = "core \(other)"
        case nil: coreName = "core default"
        }
        let isJIT = configs[Self.dolphin_cpu_core.rawValue] == "4"
        let rate = Double(configs[Self.dolphin_cpu_clock_rate.rawValue] ?? "1.00") ?? 1.0
        let clock = "\(Int((rate * 100).rounded()))%"
        var full = "CPU Core: \(coreName) · clock \(clock) · JIT \(isJIT ? "on" : "off")"
        full += " · VI skip \(configs[Self.dolphin_vi_skip.rawValue] == "enabled" ? "on" : "off")"
        if isJIT {
            full += " · fastmem arena \(configs[Self.dolphin_fastmem_arena.rawValue] == "disabled" ? "off" : "on")"
        }
        return ("\(coreName) \(clock)", full)
    }

    /// Manic MP: one line per Dolphin session in Documents/Netplay Logs, next to the
    /// RetroArch logs (Files app → Manic MP), so a slow session can be matched to
    /// the mode it ran in afterwards.
    static func appendDolphinSessionLog(game: Game, line: String) {
        let logDir = R.Path.Document.appendingPathComponent("Netplay Logs")
        try? FileManager.default.createDirectory(atPath: logDir, withIntermediateDirectories: true)
        let path = logDir.appendingPathComponent("Manic MP sessions.log")
        let stamp = ISO8601DateFormatter().string(from: Date())
        let entry = "\(stamp) \(game.gameIDForDolphin ?? "------") \(game.name) | \(line)\n"
        guard let data = entry.data(using: .utf8) else { return }
        if let handle = FileHandle(forWritingAtPath: path) {
            handle.seekToEndOfFile()
            handle.write(data)
            handle.closeFile()
        } else {
            FileManager.default.createFile(atPath: path, contents: data)
        }
    }

    static func resolvedCoreConfigs(game: Game,
                                    optimizationCoreConfigs: [Self: String],
                                    safeMode: Bool) -> [String: String]? {
        let bestSetupCoreConfigs = getBestSetupCoreConfigs(game: game)
        var resolvedCoreConfigs = optimizationCoreConfigs.mapKeysAndValues({
            ($0.key.rawValue, $0.value)
        })
        resolvedCoreConfigs = bestSetupCoreConfigs + resolvedCoreConfigs
        if !safeMode,
           let storeCoreConfigs = Prefference.defalut.getPrefference(kind: .coreOptions,
                                                                     storeKey: .coreOptionsKey(gameId: game.id, defaultCore: game.defaultCore),
                                                                     bestEfforts: true)?.coreOptionsValue {
            resolvedCoreConfigs += storeCoreConfigs
        }
        return resolvedCoreConfigs
    }
    
    static func ppssppServerAddressConfig(index: String) -> Self? {
        return SpecialCoreOption(rawValue: "ppsspp_pro_ad_hoc_server_address\(index)")
    }
}
