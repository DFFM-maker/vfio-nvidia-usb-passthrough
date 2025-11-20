# Contributing to vfio-nvidia-usb-passthrough

Thank you for your interest in contributing! This guide will help you get started.

## How You Can Contribute

### 1. Bug Reports & Issues

If you encounter problems:

- Search existing issues first
- Provide detailed information:
  - Your hardware (CPU, GPU, motherboard)
  - Linux distribution and kernel version
  - Output of `./scripts/check-iommu.sh`
  - Relevant error messages from `dmesg` or libvirt logs
  - Steps to reproduce

### 2. Documentation Improvements

Help improve the guides:

- Fix typos or unclear explanations
- Add missing information
- Update outdated instructions
- Translate to other languages

### 3. New Scripts

Useful scripts to add:

- Backup/restore VM configurations
- Automatic device hotplug
- Performance monitoring
- GPU reset helpers
- Network configuration helpers

### 4. Example Configurations

Share your working VM configs for:

- Different distributions (Fedora, Arch, etc.)
- Different use cases (streaming, CAD, etc.)
- Multi-GPU setups
- Looking Glass configurations
- SR-IOV setups

### 5. Hardware Compatibility Reports

Help others by reporting:

- CPU model and motherboard
- GPU model and VFIO compatibility
- USB controller compatibility
- Any quirks or workarounds needed

## Contribution Guidelines

### Code Style

**Bash Scripts:**
- Use 4 spaces for indentation
- Include descriptive comments
- Add error checking with `set -e`
- Use shellcheck for validation
- Include usage/help text

**XML Configurations:**
- Use 2 spaces for indentation
- Add descriptive comments
- Include hardware requirements in header

### Documentation

- Use clear, concise language
- Include command examples
- Add troubleshooting tips
- Link to official documentation
- Keep line length reasonable (80-100 chars)

### Commit Messages

Use conventional commits format:

```
type: brief description

Longer description if needed
```

Types:
- `feat:` New feature
- `fix:` Bug fix
- `docs:` Documentation changes
- `refactor:` Code refactoring
- `test:` Adding tests
- `chore:` Maintenance tasks

Examples:
```
feat: add script to reset GPU after VM shutdown

fix: correct PCI address format in bind-vfio.sh

docs: update Windows 10 installation instructions
```

## Development Setup

### Fork and Clone

```bash
# Fork on GitHub first, then:
git clone https://github.com/YOUR-USERNAME/vfio-nvidia-usb-passthrough.git
cd vfio-nvidia-usb-passthrough

# Add upstream
git remote add upstream https://github.com/DFFM-maker/vfio-nvidia-usb-passthrough.git
```

### Testing Your Changes

**Scripts:**
```bash
# Check syntax
bash -n scripts/your-script.sh

# Run shellcheck
shellcheck scripts/your-script.sh

# Test on a VM or test system
./scripts/your-script.sh
```

**Documentation:**
```bash
# Check for broken links
# Render markdown to verify formatting
```

**XML Configs:**
```bash
# Validate XML
virt-xml-validate examples/your-config.xml

# Test with virsh
sudo virsh define examples/your-config.xml
sudo virsh dumpxml vm-name
```

### Creating a Pull Request

1. Create a feature branch:
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. Make your changes:
   ```bash
   git add .
   git commit -m "feat: your feature description"
   ```

3. Keep your branch updated:
   ```bash
   git fetch upstream
   git rebase upstream/main
   ```

4. Push and create PR:
   ```bash
   git push origin feature/your-feature-name
   ```
   Then create PR on GitHub.

### PR Checklist

- [ ] Changes are minimal and focused
- [ ] Scripts have been tested
- [ ] Documentation is updated if needed
- [ ] Commit messages are clear
- [ ] No sensitive information (paths, IDs, etc.)
- [ ] Scripts are executable (`chmod +x`)
- [ ] Code follows existing style

## Code of Conduct

### Our Pledge

We aim to make this project welcoming to everyone, regardless of:
- Experience level
- Technical background
- Operating system choice
- Hardware setup

### Expected Behavior

- Be respectful and constructive
- Help others learn
- Accept feedback gracefully
- Focus on what's best for the community

### Unacceptable Behavior

- Harassment or discrimination
- Trolling or insulting comments
- Publishing others' private information
- Other unprofessional conduct

## Questions?

- Open a [Discussion](https://github.com/DFFM-maker/vfio-nvidia-usb-passthrough/discussions) for general questions
- Open an [Issue](https://github.com/DFFM-maker/vfio-nvidia-usb-passthrough/issues) for bugs
- Check [r/VFIO](https://reddit.com/r/VFIO) for community support

## Recognition

Contributors will be:
- Listed in README.md (if desired)
- Credited in relevant documentation
- Thanked for their time and effort

Thank you for contributing! 🎉
