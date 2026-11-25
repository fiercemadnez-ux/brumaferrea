extends Node

# Verifica atualizações na tela inicial. O download é feito em user:// para não
# tocar nos arquivos instalados enquanto o jogo está em execução. A aplicação
# do patch fica a cargo de um processo separado do PowerShell no Windows.

const APPLY_SCRIPT_BASE64 := "cGFyYW0oCiAgICBbUGFyYW1ldGVyKE1hbmRhdG9yeT0kdHJ1ZSldW3N0cmluZ10kQXJjaGl2ZVBhdGgsCiAgICBbUGFyYW1ldGVyKE1hbmRhdG9yeT0kdHJ1ZSldW3N0cmluZ10kQ29udGV4dFBhdGgsCiAgICBbUGFyYW1ldGVyKE1hbmRhdG9yeT0kdHJ1ZSldW3N0cmluZ10kSW5zdGFsbERpciwKICAgIFtQYXJhbWV0ZXIoTWFuZGF0b3J5PSR0cnVlKV1bc3RyaW5nXSRHYW1lRXhlLAogICAgW1BhcmFtZXRlcihNYW5kYXRvcnk9JHRydWUpXVtpbnRdJFdhaXRQaWQKKQoKJEVycm9yQWN0aW9uUHJlZmVyZW5jZSA9ICdTdG9wJwokdXBkYXRlQ29tbWl0dGVkID0gJGZhbHNlCiR3b3JrUm9vdCA9IEpvaW4tUGF0aCAkZW52OkxPQ0FMQVBQREFUQSAnQnJ1bWFmZXJyZWFcVXBkYXRlcicKJHdvcmsgPSBKb2luLVBhdGggJHdvcmtSb290IChbR3VpZF06Ok5ld0d1aWQoKS5Ub1N0cmluZygnTicpKQokc3RhZ2VSb290ID0gSm9pbi1QYXRoICR3b3JrICdzdGFnZScKJGJhY2t1cFJvb3QgPSBKb2luLVBhdGggJHdvcmsgJ2JhY2t1cCcKJHJlY29yZHMgPSBAKCkKJGluc3RhbGxSb290ID0gW1N5c3RlbS5JTy5QYXRoXTo6R2V0RnVsbFBhdGgoJEluc3RhbGxEaXIpLlRyaW1FbmQoJ1wnKQoKZnVuY3Rpb24gR2V0LVNhZmVSZWxhdGl2ZVBhdGgoW3N0cmluZ10kcmVsYXRpdmUpIHsKICAgIGlmIChbc3RyaW5nXTo6SXNOdWxsT3JXaGl0ZVNwYWNlKCRyZWxhdGl2ZSkpIHsgdGhyb3cgJ08gcGFjb3RlIGNvbnTDqW0gdW0gY2FtaW5obyB2YXppby4nIH0KICAgICRub3JtYWxpemVkID0gJHJlbGF0aXZlLlJlcGxhY2UoJy8nLCAnXCcpCiAgICBpZiAoW1N5c3RlbS5JTy5QYXRoXTo6SXNQYXRoUm9vdGVkKCRub3JtYWxpemVkKSAtb3IgJG5vcm1hbGl6ZWQgLW1hdGNoICcoXnxcXClcLlwuKFxcfCQpJyAtb3IgJG5vcm1hbGl6ZWQgLW1hdGNoICdeW0EtWmEtel06JyAtb3IgJG5vcm1hbGl6ZWQuQ29udGFpbnMoJzonKSkgewogICAgICAgIHRocm93ICJDYW1pbmhvIGludsOhbGlkbyBubyBwYWNvdGU6ICRyZWxhdGl2ZSIKICAgIH0KICAgIHJldHVybiAkbm9ybWFsaXplZAp9CgpmdW5jdGlvbiBHZXQtU2FmZVRhcmdldChbc3RyaW5nXSRyb290LCBbc3RyaW5nXSRyZWxhdGl2ZSkgewogICAgJG5vcm1hbGl6ZWQgPSBHZXQtU2FmZVJlbGF0aXZlUGF0aCAkcmVsYXRpdmUKICAgICRyb290RnVsbCA9IFtTeXN0ZW0uSU8uUGF0aF06OkdldEZ1bGxQYXRoKCRyb290KS5UcmltRW5kKCdcJykgKyAnXCcKICAgICRmdWxsID0gW1N5c3RlbS5JTy5QYXRoXTo6R2V0RnVsbFBhdGgoKEpvaW4tUGF0aCAkcm9vdEZ1bGwgJG5vcm1hbGl6ZWQpKQogICAgaWYgKC1ub3QgJGZ1bGwuU3RhcnRzV2l0aCgkcm9vdEZ1bGwsIFtTeXN0ZW0uU3RyaW5nQ29tcGFyaXNvbl06Ok9yZGluYWxJZ25vcmVDYXNlKSkgewogICAgICAgIHRocm93ICJDYW1pbmhvIGZvcmEgZGEgcGFzdGEgYXV0b3JpemFkYTogJHJlbGF0aXZlIgogICAgfQogICAgcmV0dXJuICRmdWxsCn0KCmZ1bmN0aW9uIFNob3ctVXBkYXRlRXJyb3IoW3N0cmluZ10kbWVzc2FnZSkgewogICAgdHJ5IHsKICAgICAgICBBZGQtVHlwZSAtQXNzZW1ibHlOYW1lIFN5c3RlbS5XaW5kb3dzLkZvcm1zCiAgICAgICAgW1N5c3RlbS5XaW5kb3dzLkZvcm1zLk1lc3NhZ2VCb3hdOjpTaG93KCRtZXNzYWdlLCAnQnJ1bWFmw6lycmVhIOKAlCBBdHVhbGl6YWRvcicsIFtTeXN0ZW0uV2luZG93cy5Gb3Jtcy5NZXNzYWdlQm94QnV0dG9uc106Ok9LLCBbU3lzdGVtLldpbmRvd3MuRm9ybXMuTWVzc2FnZUJveEljb25dOjpFcnJvcikgfCBPdXQtTnVsbAogICAgfSBjYXRjaCB7IH0KfQoKdHJ5IHsKICAgIGlmICgtbm90IChUZXN0LVBhdGggLUxpdGVyYWxQYXRoICRBcmNoaXZlUGF0aCAtUGF0aFR5cGUgTGVhZikpIHsgdGhyb3cgJ08gYXJxdWl2byBkbyBwYXRjaCBuw6NvIGZvaSBlbmNvbnRyYWRvLicgfQogICAgaWYgKC1ub3QgKFRlc3QtUGF0aCAtTGl0ZXJhbFBhdGggJENvbnRleHRQYXRoIC1QYXRoVHlwZSBMZWFmKSkgeyB0aHJvdyAnT3MgZGFkb3MgZG8gcGF0Y2ggbsOjbyBmb3JhbSBlbmNvbnRyYWRvcy4nIH0KICAgICRjb250ZXh0ID0gR2V0LUNvbnRlbnQgLUxpdGVyYWxQYXRoICRDb250ZXh0UGF0aCAtUmF3IC1FbmNvZGluZyBVVEY4IHwgQ29udmVydEZyb20tSnNvbgogICAgJGV4cGVjdGVkSGFzaCA9IChbc3RyaW5nXSRjb250ZXh0LnNoYTI1NikuVG9Mb3dlckludmFyaWFudCgpCiAgICBpZiAoJGV4cGVjdGVkSGFzaCAtbm90bWF0Y2ggJ15bMC05YS1mXXs2NH0kJykgeyB0aHJvdyAnTyBtYW5pZmVzdG8gY29udMOpbSB1bSBTSEEtMjU2IGludsOhbGlkby4nIH0KICAgICRhY3R1YWxIYXNoID0gKEdldC1GaWxlSGFzaCAtTGl0ZXJhbFBhdGggJEFyY2hpdmVQYXRoIC1BbGdvcml0aG0gU0hBMjU2KS5IYXNoLlRvTG93ZXJJbnZhcmlhbnQoKQogICAgaWYgKCRhY3R1YWxIYXNoIC1uZSAkZXhwZWN0ZWRIYXNoKSB7IHRocm93ICdBIHZlcmlmaWNhw6fDo28gZGUgaW50ZWdyaWRhZGUgZG8gZG93bmxvYWQgZmFsaG91LiBOZW5odW0gYXJxdWl2byBmb2kgYWx0ZXJhZG8uJyB9CgogICAgTmV3LUl0ZW0gLUl0ZW1UeXBlIERpcmVjdG9yeSAtUGF0aCAkc3RhZ2VSb290IC1Gb3JjZSB8IE91dC1OdWxsCiAgICBOZXctSXRlbSAtSXRlbVR5cGUgRGlyZWN0b3J5IC1QYXRoICRiYWNrdXBSb290IC1Gb3JjZSB8IE91dC1OdWxsCiAgICBBZGQtVHlwZSAtQXNzZW1ibHlOYW1lIFN5c3RlbS5JTy5Db21wcmVzc2lvbi5GaWxlU3lzdGVtCiAgICAkemlwID0gW1N5c3RlbS5JTy5Db21wcmVzc2lvbi5aaXBGaWxlXTo6T3BlblJlYWQoJEFyY2hpdmVQYXRoKQogICAgJHN0YWdlZFJlbGF0aXZlUGF0aHMgPSBAKCkKICAgIHRyeSB7CiAgICAgICAgZm9yZWFjaCAoJGVudHJ5IGluICR6aXAuRW50cmllcykgewogICAgICAgICAgICBpZiAoJGVudHJ5LkZ1bGxOYW1lLkVuZHNXaXRoKCcvJykgLW9yICRlbnRyeS5GdWxsTmFtZS5FbmRzV2l0aCgnXCcpKSB7IGNvbnRpbnVlIH0KICAgICAgICAgICAgJHJlbGF0aXZlID0gR2V0LVNhZmVSZWxhdGl2ZVBhdGggJGVudHJ5LkZ1bGxOYW1lCiAgICAgICAgICAgICR0YXJnZXQgPSBHZXQtU2FmZVRhcmdldCAkc3RhZ2VSb290ICRyZWxhdGl2ZQogICAgICAgICAgICAkcGFyZW50ID0gU3BsaXQtUGF0aCAtUGFyZW50ICR0YXJnZXQKICAgICAgICAgICAgaWYgKC1ub3QgKFRlc3QtUGF0aCAtTGl0ZXJhbFBhdGggJHBhcmVudCAtUGF0aFR5cGUgQ29udGFpbmVyKSkgeyBOZXctSXRlbSAtSXRlbVR5cGUgRGlyZWN0b3J5IC1QYXRoICRwYXJlbnQgLUZvcmNlIHwgT3V0LU51bGwgfQogICAgICAgICAgICAkc291cmNlU3RyZWFtID0gJGVudHJ5Lk9wZW4oKQogICAgICAgICAgICB0cnkgewogICAgICAgICAgICAgICAgJHRhcmdldFN0cmVhbSA9IFtTeXN0ZW0uSU8uRmlsZV06OkNyZWF0ZSgkdGFyZ2V0KQogICAgICAgICAgICAgICAgdHJ5IHsgJHNvdXJjZVN0cmVhbS5Db3B5VG8oJHRhcmdldFN0cmVhbSkgfSBmaW5hbGx5IHsgJHRhcmdldFN0cmVhbS5EaXNwb3NlKCkgfQogICAgICAgICAgICB9IGZpbmFsbHkgeyAkc291cmNlU3RyZWFtLkRpc3Bvc2UoKSB9CiAgICAgICAgICAgICRzdGFnZWRSZWxhdGl2ZVBhdGhzICs9ICRyZWxhdGl2ZQogICAgICAgIH0KICAgIH0gZmluYWxseSB7ICR6aXAuRGlzcG9zZSgpIH0KICAgICRtYW5pZmVzdERlbGV0ZUNvdW50ID0gMAogICAgaWYgKCRjb250ZXh0LmRlbGV0ZV9maWxlcyAtaXMgW1N5c3RlbS5BcnJheV0pIHsgJG1hbmlmZXN0RGVsZXRlQ291bnQgPSBAKCRjb250ZXh0LmRlbGV0ZV9maWxlcykuQ291bnQgfQogICAgZWxzZWlmICgkbnVsbCAtbmUgJGNvbnRleHQuZGVsZXRlX2ZpbGVzIC1hbmQgW3N0cmluZ10kY29udGV4dC5kZWxldGVfZmlsZXMgLW5lICcnKSB7ICRtYW5pZmVzdERlbGV0ZUNvdW50ID0gMSB9CiAgICBpZiAoJHN0YWdlZFJlbGF0aXZlUGF0aHMuQ291bnQgLWVxIDAgLWFuZCAkbWFuaWZlc3REZWxldGVDb3VudCAtZXEgMCkgeyB0aHJvdyAnTyBwYWNvdGUgZGUgYXR1YWxpemHDp8OjbyBuw6NvIGNvbnTDqW0gYWx0ZXJhw6fDtWVzLicgfQoKICAgICMgU8OzIGRlcG9pcyBkZSBiYWl4YXIsIHZhbGlkYXIgbyBoYXNoIGUgZXh0cmFpciBwYXJhIHVtYSDDoXJlYSBkZSBzdGFnaW5nIG8KICAgICMgYXR1YWxpemFkb3IgZXNwZXJhIG8gcHJvY2Vzc28gZG8gam9nbyBlbmNlcnJhciBlIGNvbWXDp2EgYSBhbHRlcmHDp8Ojby4KICAgIHRyeSB7IFdhaXQtUHJvY2VzcyAtSWQgJFdhaXRQaWQgLVRpbWVvdXQgMTgwIC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlIH0gY2F0Y2ggeyB9CiAgICBpZiAoR2V0LVByb2Nlc3MgLUlkICRXYWl0UGlkIC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlKSB7CiAgICAgICAgdGhyb3cgJ08gam9nbyBuw6NvIGZlY2hvdSBhIHRlbXBvLiBGZWNoZSBCcnVtYWbDqXJyZWEgZSB0ZW50ZSBhdHVhbGl6YXIgbm92YW1lbnRlLicKICAgIH0KCiAgICAkZGVsZXRlUGF0aHMgPSBAKCkKICAgIGlmICgkY29udGV4dC5kZWxldGVfZmlsZXMgLWlzIFtTeXN0ZW0uQXJyYXldKSB7ICRkZWxldGVQYXRocyA9IEAoJGNvbnRleHQuZGVsZXRlX2ZpbGVzKSB9CiAgICBlbHNlaWYgKCRudWxsIC1uZSAkY29udGV4dC5kZWxldGVfZmlsZXMgLWFuZCBbc3RyaW5nXSRjb250ZXh0LmRlbGV0ZV9maWxlcyAtbmUgJycpIHsgJGRlbGV0ZVBhdGhzID0gQChbc3RyaW5nXSRjb250ZXh0LmRlbGV0ZV9maWxlcykgfQogICAgJGFmZmVjdGVkID0gQCgkc3RhZ2VkUmVsYXRpdmVQYXRocyArICRkZWxldGVQYXRocyB8IFNlbGVjdC1PYmplY3QgLVVuaXF1ZSkKCiAgICAjIEJhY2t1cHMgZGUgdG9kb3Mgb3MgYXJxdWl2b3MgcXVlIHBvZGVtIHNlciB0b2NhZG9zIHBlcm1pdGVtIHJvbGxiYWNrIHNlCiAgICAjIGFsZ3VtYSBjw7NwaWEgb3UgZXhjbHVzw6NvIGZhbGhhciBubyBtZWlvIGRvIHByb2Nlc3NvLgogICAgZm9yZWFjaCAoJHJlbGF0aXZlIGluICRhZmZlY3RlZCkgewogICAgICAgICRzYWZlUmVsYXRpdmUgPSBHZXQtU2FmZVJlbGF0aXZlUGF0aCAoW3N0cmluZ10kcmVsYXRpdmUpCiAgICAgICAgJHRhcmdldFBhdGggPSBHZXQtU2FmZVRhcmdldCAkaW5zdGFsbFJvb3QgJHNhZmVSZWxhdGl2ZQogICAgICAgICRiYWNrdXBQYXRoID0gR2V0LVNhZmVUYXJnZXQgJGJhY2t1cFJvb3QgJHNhZmVSZWxhdGl2ZQogICAgICAgICRleGlzdGVkID0gVGVzdC1QYXRoIC1MaXRlcmFsUGF0aCAkdGFyZ2V0UGF0aCAtUGF0aFR5cGUgTGVhZgogICAgICAgIGlmICgkZXhpc3RlZCkgewogICAgICAgICAgICAkYmFja3VwUGFyZW50ID0gU3BsaXQtUGF0aCAtUGFyZW50ICRiYWNrdXBQYXRoCiAgICAgICAgICAgIGlmICgtbm90IChUZXN0LVBhdGggLUxpdGVyYWxQYXRoICRiYWNrdXBQYXJlbnQgLVBhdGhUeXBlIENvbnRhaW5lcikpIHsgTmV3LUl0ZW0gLUl0ZW1UeXBlIERpcmVjdG9yeSAtUGF0aCAkYmFja3VwUGFyZW50IC1Gb3JjZSB8IE91dC1OdWxsIH0KICAgICAgICAgICAgQ29weS1JdGVtIC1MaXRlcmFsUGF0aCAkdGFyZ2V0UGF0aCAtRGVzdGluYXRpb24gJGJhY2t1cFBhdGggLUZvcmNlCiAgICAgICAgfQogICAgICAgICRyZWNvcmRzICs9IFtQU0N1c3RvbU9iamVjdF1AeyBSZWxhdGl2ZSA9ICRzYWZlUmVsYXRpdmU7IEV4aXN0ZWQgPSAkZXhpc3RlZCB9CiAgICB9CgogICAgdHJ5IHsKICAgICAgICBmb3JlYWNoICgkcmVsYXRpdmUgaW4gJHN0YWdlZFJlbGF0aXZlUGF0aHMpIHsKICAgICAgICAgICAgJHNvdXJjZVBhdGggPSBHZXQtU2FmZVRhcmdldCAkc3RhZ2VSb290ICRyZWxhdGl2ZQogICAgICAgICAgICAkdGFyZ2V0UGF0aCA9IEdldC1TYWZlVGFyZ2V0ICRpbnN0YWxsUm9vdCAkcmVsYXRpdmUKICAgICAgICAgICAgJHRhcmdldFBhcmVudCA9IFNwbGl0LVBhdGggLVBhcmVudCAkdGFyZ2V0UGF0aAogICAgICAgICAgICBpZiAoLW5vdCAoVGVzdC1QYXRoIC1MaXRlcmFsUGF0aCAkdGFyZ2V0UGFyZW50IC1QYXRoVHlwZSBDb250YWluZXIpKSB7IE5ldy1JdGVtIC1JdGVtVHlwZSBEaXJlY3RvcnkgLVBhdGggJHRhcmdldFBhcmVudCAtRm9yY2UgfCBPdXQtTnVsbCB9CiAgICAgICAgICAgIENvcHktSXRlbSAtTGl0ZXJhbFBhdGggJHNvdXJjZVBhdGggLURlc3RpbmF0aW9uICR0YXJnZXRQYXRoIC1Gb3JjZQogICAgICAgIH0KICAgICAgICBmb3JlYWNoICgkcmVsYXRpdmUgaW4gJGRlbGV0ZVBhdGhzKSB7CiAgICAgICAgICAgICR0YXJnZXRQYXRoID0gR2V0LVNhZmVUYXJnZXQgJGluc3RhbGxSb290IChbc3RyaW5nXSRyZWxhdGl2ZSkKICAgICAgICAgICAgaWYgKFRlc3QtUGF0aCAtTGl0ZXJhbFBhdGggJHRhcmdldFBhdGggLVBhdGhUeXBlIExlYWYpIHsgUmVtb3ZlLUl0ZW0gLUxpdGVyYWxQYXRoICR0YXJnZXRQYXRoIC1Gb3JjZSB9CiAgICAgICAgfQogICAgICAgICR1cGRhdGVDb21taXR0ZWQgPSAkdHJ1ZQogICAgfSBjYXRjaCB7CiAgICAgICAgZm9yZWFjaCAoJHJlY29yZCBpbiAkcmVjb3JkcykgewogICAgICAgICAgICAkdGFyZ2V0UGF0aCA9IEdldC1TYWZlVGFyZ2V0ICRpbnN0YWxsUm9vdCAkcmVjb3JkLlJlbGF0aXZlCiAgICAgICAgICAgIGlmICgkcmVjb3JkLkV4aXN0ZWQpIHsKICAgICAgICAgICAgICAgICRiYWNrdXBQYXRoID0gR2V0LVNhZmVUYXJnZXQgJGJhY2t1cFJvb3QgJHJlY29yZC5SZWxhdGl2ZQogICAgICAgICAgICAgICAgaWYgKFRlc3QtUGF0aCAtTGl0ZXJhbFBhdGggJGJhY2t1cFBhdGggLVBhdGhUeXBlIExlYWYpIHsKICAgICAgICAgICAgICAgICAgICAkdGFyZ2V0UGFyZW50ID0gU3BsaXQtUGF0aCAtUGFyZW50ICR0YXJnZXRQYXRoCiAgICAgICAgICAgICAgICAgICAgaWYgKC1ub3QgKFRlc3QtUGF0aCAtTGl0ZXJhbFBhdGggJHRhcmdldFBhcmVudCAtUGF0aFR5cGUgQ29udGFpbmVyKSkgeyBOZXctSXRlbSAtSXRlbVR5cGUgRGlyZWN0b3J5IC1QYXRoICR0YXJnZXRQYXJlbnQgLUZvcmNlIHwgT3V0LU51bGwgfQogICAgICAgICAgICAgICAgICAgIENvcHktSXRlbSAtTGl0ZXJhbFBhdGggJGJhY2t1cFBhdGggLURlc3RpbmF0aW9uICR0YXJnZXRQYXRoIC1Gb3JjZQogICAgICAgICAgICAgICAgfQogICAgICAgICAgICB9IGVsc2VpZiAoVGVzdC1QYXRoIC1MaXRlcmFsUGF0aCAkdGFyZ2V0UGF0aCAtUGF0aFR5cGUgTGVhZikgewogICAgICAgICAgICAgICAgUmVtb3ZlLUl0ZW0gLUxpdGVyYWxQYXRoICR0YXJnZXRQYXRoIC1Gb3JjZQogICAgICAgICAgICB9CiAgICAgICAgfQogICAgICAgIHRocm93CiAgICB9CgogICAgJGdhbWVQYXRoID0gR2V0LVNhZmVUYXJnZXQgJGluc3RhbGxSb290ICRHYW1lRXhlCiAgICBpZiAoLW5vdCAoVGVzdC1QYXRoIC1MaXRlcmFsUGF0aCAkZ2FtZVBhdGggLVBhdGhUeXBlIExlYWYpKSB7IHRocm93ICJBIGF0dWFsaXphw6fDo28gZm9pIGFwbGljYWRhLCBtYXMgbyBleGVjdXTDoXZlbCBuw6NvIGZvaSBlbmNvbnRyYWRvOiAkZ2FtZVBhdGgiIH0KICAgIFN0YXJ0LVByb2Nlc3MgLUZpbGVQYXRoICRnYW1lUGF0aCAtV29ya2luZ0RpcmVjdG9yeSAkaW5zdGFsbFJvb3QKICAgIFN0YXJ0LVNsZWVwIC1NaWxsaXNlY29uZHMgOTAwCiAgICBSZW1vdmUtSXRlbSAtTGl0ZXJhbFBhdGggJHdvcmsgLVJlY3Vyc2UgLUZvcmNlIC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlCn0gY2F0Y2ggewogICAgJGRldGFpbCA9ICRfLkV4Y2VwdGlvbi5NZXNzYWdlCiAgICBpZiAoLW5vdCAkdXBkYXRlQ29tbWl0dGVkKSB7CiAgICAgICAgZm9yZWFjaCAoJHJlY29yZCBpbiAkcmVjb3JkcykgewogICAgICAgICAgICB0cnkgewogICAgICAgICAgICAgICAgJHRhcmdldFBhdGggPSBHZXQtU2FmZVRhcmdldCAkaW5zdGFsbFJvb3QgJHJlY29yZC5SZWxhdGl2ZQogICAgICAgICAgICAgICAgaWYgKCRyZWNvcmQuRXhpc3RlZCkgewogICAgICAgICAgICAgICAgICAgICRiYWNrdXBQYXRoID0gR2V0LVNhZmVUYXJnZXQgJGJhY2t1cFJvb3QgJHJlY29yZC5SZWxhdGl2ZQogICAgICAgICAgICAgICAgICAgIGlmIChUZXN0LVBhdGggLUxpdGVyYWxQYXRoICRiYWNrdXBQYXRoIC1QYXRoVHlwZSBMZWFmKSB7CiAgICAgICAgICAgICAgICAgICAgICAgICR0YXJnZXRQYXJlbnQgPSBTcGxpdC1QYXRoIC1QYXJlbnQgJHRhcmdldFBhdGgKICAgICAgICAgICAgICAgICAgICAgICAgaWYgKC1ub3QgKFRlc3QtUGF0aCAtTGl0ZXJhbFBhdGggJHRhcmdldFBhcmVudCAtUGF0aFR5cGUgQ29udGFpbmVyKSkgeyBOZXctSXRlbSAtSXRlbVR5cGUgRGlyZWN0b3J5IC1QYXRoICR0YXJnZXRQYXJlbnQgLUZvcmNlIHwgT3V0LU51bGwgfQogICAgICAgICAgICAgICAgICAgICAgICBDb3B5LUl0ZW0gLUxpdGVyYWxQYXRoICRiYWNrdXBQYXRoIC1EZXN0aW5hdGlvbiAkdGFyZ2V0UGF0aCAtRm9yY2UKICAgICAgICAgICAgICAgICAgICB9CiAgICAgICAgICAgICAgICB9IGVsc2VpZiAoVGVzdC1QYXRoIC1MaXRlcmFsUGF0aCAkdGFyZ2V0UGF0aCAtUGF0aFR5cGUgTGVhZikgewogICAgICAgICAgICAgICAgICAgIFJlbW92ZS1JdGVtIC1MaXRlcmFsUGF0aCAkdGFyZ2V0UGF0aCAtRm9yY2UKICAgICAgICAgICAgICAgIH0KICAgICAgICAgICAgfSBjYXRjaCB7IH0KICAgICAgICB9CiAgICB9CiAgICBTaG93LVVwZGF0ZUVycm9yICgiTsOjbyBmb2kgcG9zc8OtdmVsIGNvbmNsdWlyIGEgYXR1YWxpemHDp8OjbyBkZSBCcnVtYWbDqXJyZWEuXG5cbiIgKyAkZGV0YWlsICsgIlxuXG5PIHNhdmUgZmljYSBzZXBhcmFkbyBkb3MgYXJxdWl2b3MgZG8gam9nby4iKQogICAgJGdhbWVQYXRoID0gSm9pbi1QYXRoICRpbnN0YWxsUm9vdCAkR2FtZUV4ZQogICAgaWYgKFRlc3QtUGF0aCAtTGl0ZXJhbFBhdGggJGdhbWVQYXRoIC1QYXRoVHlwZSBMZWFmKSB7CiAgICAgICAgdHJ5IHsgU3RhcnQtUHJvY2VzcyAtRmlsZVBhdGggJGdhbWVQYXRoIC1Xb3JraW5nRGlyZWN0b3J5ICRpbnN0YWxsUm9vdCB9IGNhdGNoIHsgfQogICAgfQp9IGZpbmFsbHkgewogICAgaWYgKFRlc3QtUGF0aCAtTGl0ZXJhbFBhdGggJENvbnRleHRQYXRoIC1QYXRoVHlwZSBMZWFmKSB7IFJlbW92ZS1JdGVtIC1MaXRlcmFsUGF0aCAkQ29udGV4dFBhdGggLUZvcmNlIC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlIH0KfQo="
const MANIFEST_TIMEOUT := 10.0
const GAME_NAME := "Os Cânticos dos Sete: Brumaférrea"
const DEFAULT_ITCH_PAGE_URL := "https://ravenhold.itch.io/brumaferrea"
const ITCH_LATEST_ENDPOINT := "https://api.itch.io/wharf/latest"

var _itch_latest_request: HTTPRequest = null
var _manifest_request: HTTPRequest = null
var _download_request: HTTPRequest = null
var _manifest: Dictionary = {}
var _prompt: ConfirmationDialog = null
var _error_dialog: AcceptDialog = null
var _progress_layer: CanvasLayer = null
var _progress_label: Label = null
var _progress_bar: ProgressBar = null
var _download_path := ""
var _manifest_url := ""
var _itch_latest_version := ""
var _itch_page_url := DEFAULT_ITCH_PAGE_URL
var _check_started := false
var _download_started := false


func check_for_update() -> void:
	if _check_started:
		return
	_check_started = true
	# Esta verificação só roda numa build Windows exportada, não no editor.
	if OS.has_feature("editor") or OS.get_name() != "Windows":
		return
	var itch_target := str(ProjectSettings.get_setting("application/config/update_itch_target", "ravenhold/brumaferrea")).strip_edges()
	var itch_channel := str(ProjectSettings.get_setting("application/config/update_itch_channel", "windows")).strip_edges()
	_itch_page_url = str(ProjectSettings.get_setting("application/config/update_game_page", DEFAULT_ITCH_PAGE_URL)).strip_edges()
	if itch_target.is_empty() or itch_channel.is_empty() or not _itch_page_url.begins_with("https://"):
		return
	# O itch.io só retorna `latest` depois que uma build foi enviada ao canal
	# com --userversion via Butler. Um upload manual pelo navegador não basta.
	var request_url := "%s?target=%s&channel_name=%s&v=%s" % [
		ITCH_LATEST_ENDPOINT,
		itch_target.uri_encode(),
		itch_channel.uri_encode(),
		str(Time.get_unix_time_from_system())
	]
	_itch_latest_request = HTTPRequest.new()
	_itch_latest_request.name = "ItchLatestVersionRequest"
	_itch_latest_request.timeout = MANIFEST_TIMEOUT
	_itch_latest_request.max_redirects = 8
	add_child(_itch_latest_request)
	_itch_latest_request.request_completed.connect(_on_itch_latest_request_completed)
	var request_error := _itch_latest_request.request(request_url, ["Cache-Control: no-cache"])
	if request_error != OK:
		_itch_latest_request.queue_free()
		_itch_latest_request = null


func _on_itch_latest_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if is_instance_valid(_itch_latest_request):
		_itch_latest_request.queue_free()
	_itch_latest_request = null
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		return
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not (parsed is Dictionary):
		return
	var remote_version := str(parsed.get("latest", "")).strip_edges()
	var current_version := str(ProjectSettings.get_setting("application/config/version", "0.1.0")).strip_edges()
	# Sem user-version no canal, a API não consegue informar uma versão pública.
	if not _is_newer_version(remote_version, current_version):
		return
	_itch_latest_version = remote_version
	_manifest_url = str(ProjectSettings.get_setting("application/config/update_manifest_url", "")).strip_edges()
	if not _is_public_https_url(_manifest_url):
		_show_manual_update_prompt(current_version, remote_version)
		return
	_request_update_manifest(current_version)


func _request_update_manifest(current_version: String) -> void:
	_manifest_request = HTTPRequest.new()
	_manifest_request.name = "UpdateManifestRequest"
	_manifest_request.timeout = MANIFEST_TIMEOUT
	_manifest_request.max_redirects = 8
	add_child(_manifest_request)
	_manifest_request.set_meta("current_version", current_version)
	_manifest_request.request_completed.connect(_on_manifest_request_completed)
	var request_url := _manifest_url
	var separator := "&" if request_url.contains("?") else "?"
	request_url += separator + "v=" + str(Time.get_unix_time_from_system())
	var request_error := _manifest_request.request(request_url, ["Cache-Control: no-cache"])
	if request_error != OK:
		_manifest_request.queue_free()
		_manifest_request = null
		_show_manual_update_prompt(current_version, _itch_latest_version)


func _on_manifest_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var current_version := str(_manifest_request.get_meta("current_version", ProjectSettings.get_setting("application/config/version", "0.1.0"))) if is_instance_valid(_manifest_request) else str(ProjectSettings.get_setting("application/config/version", "0.1.0"))
	if is_instance_valid(_manifest_request):
		_manifest_request.queue_free()
	_manifest_request = null
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		_show_manual_update_prompt(current_version, _itch_latest_version)
		return
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not (parsed is Dictionary):
		_show_manual_update_prompt(current_version, _itch_latest_version)
		return
	var remote: Dictionary = parsed
	var remote_version := str(remote.get("version", "")).strip_edges()
	# Evita oferecer um pacote de patch diferente da build publicada no itch.io.
	if remote_version != _itch_latest_version or not _is_newer_version(remote_version, current_version):
		push_warning("A versão do manifesto de atualização não corresponde à build mais recente do itch.io.")
		_show_manual_update_prompt(current_version, _itch_latest_version)
		return
	var download_url := str(remote.get("download_url", "")).strip_edges()
	var expected_hash := str(remote.get("sha256", "")).strip_edges().to_lower()
	if not _is_public_https_url(download_url) or not _is_sha256(expected_hash):
		push_warning("Manifesto de atualização inválido: URL HTTPS ou SHA-256 ausente.")
		_show_manual_update_prompt(current_version, remote_version)
		return
	_manifest = remote.duplicate(true)
	_show_update_prompt(current_version, remote_version, str(remote.get("notes", "Correções e melhorias.")))


func _show_update_prompt(current_version: String, remote_version: String, notes: String) -> void:
	_prompt = ConfirmationDialog.new()
	_prompt.title = "Atualização disponível"
	_prompt.dialog_text = "%s\n\nVersão instalada: %s\nNova versão: %s\n\n%s\n\nSe aceitar, o jogo será fechado, atualizado na mesma pasta e reaberto." % [GAME_NAME, current_version, remote_version, notes]
	_prompt.min_size = Vector2i(560, 270)
	_prompt.get_ok_button().text = "Atualizar agora"
	_prompt.get_cancel_button().text = "Jogar mesmo assim"
	_prompt.confirmed.connect(_begin_patch_download)
	add_child(_prompt)
	_prompt.popup_centered(Vector2i(600, 300))


func _show_manual_update_prompt(current_version: String, remote_version: String) -> void:
	# A versão foi detectada no itch.io, mas não há um patch hospedado/configurado.
	# A página é oferecida como alternativa sem fingir que a atualização foi instalada.
	_prompt = ConfirmationDialog.new()
	_prompt.title = "Nova versão no itch.io"
	_prompt.dialog_text = "%s\n\nVersão instalada: %s\nVersão publicada: %s\n\nEsta instalação ainda não tem um pacote de atualização automática configurado. Você pode abrir a página do jogo para baixar a versão nova manualmente." % [GAME_NAME, current_version, remote_version]
	_prompt.min_size = Vector2i(560, 240)
	_prompt.get_ok_button().text = "Abrir página do itch.io"
	_prompt.get_cancel_button().text = "Jogar mesmo assim"
	_prompt.confirmed.connect(_open_itch_page)
	add_child(_prompt)
	_prompt.popup_centered(Vector2i(600, 270))


func _open_itch_page() -> void:
	OS.shell_open(_itch_page_url)


func _is_public_https_url(value: String) -> bool:
	var normalized := value.strip_edges()
	return normalized.begins_with("https://") and not normalized.contains("SEU_USUARIO") and not normalized.contains("SEU_REPOSITORIO")


func _begin_patch_download() -> void:
	if _download_started:
		return
	_download_started = true
	if is_instance_valid(_prompt):
		_prompt.queue_free()
		_prompt = null
	var url := str(_manifest.get("download_url", "")).strip_edges()
	var sha := str(_manifest.get("sha256", "")).strip_edges().to_lower()
	if not url.begins_with("https://") or not _is_sha256(sha):
		_show_error("O manifesto da atualização está incompleto ou inválido.")
		return
	var update_dir := OS.get_user_data_dir().path_join("updates")
	DirAccess.make_dir_recursive_absolute(update_dir)
	_download_path = update_dir.path_join("update.zip")
	if FileAccess.file_exists(_download_path):
		DirAccess.remove_absolute(_download_path)
	_show_progress()
	_download_request = HTTPRequest.new()
	_download_request.name = "UpdateArchiveRequest"
	_download_request.timeout = 0.0
	_download_request.max_redirects = 8
	_download_request.download_file = _download_path
	add_child(_download_request)
	_download_request.request_completed.connect(_on_patch_download_completed)
	var request_error := _download_request.request(url)
	if request_error != OK:
		_download_request.queue_free()
		_download_request = null
		_hide_progress()
		_show_error("Não foi possível iniciar o download da atualização. Confira a conexão e tente novamente.")
		_download_started = false


func _process(_delta: float) -> void:
	if not is_instance_valid(_download_request) or not is_instance_valid(_progress_bar):
		return
	var total := _download_request.get_body_size()
	var downloaded := _download_request.get_downloaded_bytes()
	if total > 0:
		_progress_bar.indeterminate = false
		_progress_bar.value = clampf(float(downloaded) / float(total) * 100.0, 0.0, 100.0)
		if is_instance_valid(_progress_label):
			_progress_label.text = "Baixando atualização: %d%%" % int(_progress_bar.value)
	else:
		_progress_bar.indeterminate = true
		if is_instance_valid(_progress_label):
			_progress_label.text = "Baixando atualização…"


func _on_patch_download_completed(result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	if is_instance_valid(_download_request):
		_download_request.queue_free()
	_download_request = null
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		_hide_progress()
		_download_started = false
		_show_error("O download da atualização falhou. Nenhum arquivo do jogo foi alterado.")
		return
	if not FileAccess.file_exists(_download_path):
		_hide_progress()
		_download_started = false
		_show_error("O arquivo da atualização não foi encontrado depois do download.")
		return
	var actual_hash := FileAccess.get_sha256(_download_path).to_lower()
	var expected_hash := str(_manifest.get("sha256", "")).to_lower()
	if actual_hash != expected_hash:
		DirAccess.remove_absolute(_download_path)
		_hide_progress()
		_download_started = false
		_show_error("A verificação de integridade falhou. A atualização foi descartada e o jogo não foi alterado.")
		return
	_hide_progress()
	_launch_patch_applier()


func _launch_patch_applier() -> void:
	var updater_script := Marshalls.base64_to_utf8(APPLY_SCRIPT_BASE64)
	if updater_script.is_empty():
		_show_error("Não foi possível carregar o atualizador. O jogo não foi alterado.")
		_download_started = false
		return
	var user_update_dir := OS.get_user_data_dir().path_join("updates")
	DirAccess.make_dir_recursive_absolute(user_update_dir)
	var updater_script_path := user_update_dir.path_join("apply_update.ps1")
	var script_file := FileAccess.open(updater_script_path, FileAccess.WRITE)
	if script_file == null:
		_show_error("Não foi possível preparar o atualizador no Windows. O jogo não foi alterado.")
		_download_started = false
		return
	script_file.store_string(updater_script)
	script_file.close()
	var context_path := user_update_dir.path_join("update_context.json")
	var context := {
		"version": str(_manifest.get("version", "")),
		"sha256": str(_manifest.get("sha256", "")),
		"delete_files": _manifest.get("delete_files", []) if _manifest.get("delete_files", []) is Array else []
	}
	var context_file := FileAccess.open(context_path, FileAccess.WRITE)
	if context_file == null:
		_show_error("Não foi possível preparar os dados da atualização. O jogo não foi alterado.")
		_download_started = false
		return
	context_file.store_string(JSON.stringify(context, "\t"))
	context_file.close()
	var executable_path := OS.get_executable_path()
	var install_dir := executable_path.get_base_dir()
	var executable_name := executable_path.get_file()
	var args := PackedStringArray([
		"-NoProfile", "-ExecutionPolicy", "Bypass", "-WindowStyle", "Hidden",
		"-File", updater_script_path,
		"-ArchivePath", _download_path,
		"-ContextPath", context_path,
		"-InstallDir", install_dir,
		"-GameExe", executable_name,
		"-WaitPid", str(OS.get_process_id())
	])
	if is_instance_valid(get_parent()) and get_parent().has_method("_save_campaign"):
		get_parent().call("_save_campaign", false)
	var updater_pid := OS.create_process("powershell.exe", args, false)
	if updater_pid <= 0:
		_show_error("O Windows não conseguiu iniciar o processo de atualização. O jogo não foi alterado.")
		_download_started = false
		return
	# O processo auxiliar espera o jogo fechar, verifica o pacote e aplica o patch.
	get_tree().quit()


func _show_progress() -> void:
	_progress_layer = CanvasLayer.new()
	_progress_layer.layer = 200
	add_child(_progress_layer)
	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.008, 0.009, 0.012, 0.88)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_progress_layer.add_child(backdrop)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_progress_layer.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(480.0, 132.0)
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	column.add_theme_constant_override("margin_left", 18)
	column.add_theme_constant_override("margin_right", 18)
	column.add_theme_constant_override("margin_top", 18)
	column.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(column)
	_progress_label = Label.new()
	_progress_label.text = "Preparando o download…"
	_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_progress_label)
	_progress_bar = ProgressBar.new()
	_progress_bar.min_value = 0.0
	_progress_bar.max_value = 100.0
	_progress_bar.value = 0.0
	_progress_bar.indeterminate = true
	column.add_child(_progress_bar)


func _hide_progress() -> void:
	if is_instance_valid(_progress_layer):
		_progress_layer.queue_free()
	_progress_layer = null
	_progress_label = null
	_progress_bar = null


func _show_error(message: String) -> void:
	if is_instance_valid(_error_dialog):
		_error_dialog.queue_free()
	_error_dialog = AcceptDialog.new()
	_error_dialog.title = "Atualização não concluída"
	_error_dialog.dialog_text = message
	_error_dialog.min_size = Vector2i(480, 150)
	add_child(_error_dialog)
	_error_dialog.popup_centered(Vector2i(500, 170))


func _is_newer_version(remote_version: String, local_version: String) -> bool:
	if not _is_valid_version(remote_version) or not _is_valid_version(local_version):
		return false
	var remote_parts := remote_version.split(".")
	var local_parts := local_version.split(".")
	for index in range(3):
		var remote_part := int(remote_parts[index])
		var local_part := int(local_parts[index])
		if remote_part > local_part:
			return true
		if remote_part < local_part:
			return false
	return false


func _is_valid_version(value: String) -> bool:
	var parts := value.split(".")
	if parts.size() != 3:
		return false
	for part in parts:
		if part.is_empty() or not part.is_valid_int() or int(part) < 0:
			return false
	return true


func _is_sha256(value: String) -> bool:
	if value.length() != 64:
		return false
	for character in value:
		if not (character in "0123456789abcdef"):
			return false
	return true
