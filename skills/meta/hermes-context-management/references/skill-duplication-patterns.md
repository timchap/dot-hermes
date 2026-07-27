# Skill Content Duplication Patterns

Common duplication patterns found during systematic skill library reviews and surgical fix approaches.

## Duplication Pattern Types

### 1. Copy-Paste Section Duplicates
**Pattern**: Entire sections (especially "When to Use" or "Overview") appearing twice.
**Example**: Two identical "When to Use" sections with slightly different wording.
**Fix**: Merge into single section, preserving the more complete version.

### 2. Orphaned Text Fragments  
**Pattern**: Incomplete sentences or phrases left behind from editing.
**Example**: " and saving as `.excalidraw` files. These files can be drag-and-dropped..."
**Fix**: Remove the orphaned fragment, ensure context flows properly.

### 3. Duplicate Headers
**Pattern**: Section headers appearing multiple times.
**Example**: "### Injecting 1Password Secrets into MCP Headers" appearing twice.
**Fix**: Remove the duplicate header, merge any unique content below it.

### 4. Partial Overlapping Content
**Pattern**: Similar but not identical descriptions.
**Example**: Different phrasings of the same concept in overview vs. usage sections.
**Fix**: Choose the clearest version, remove or rewrite the redundant one.

## Fix Strategy

1. **Use surgical patches**: Apply `patch` tool targeting exact duplicated text
2. **Preserve structure**: Maintain skill organization while removing redundancy
3. **Verify diffs**: Check patch output to ensure only intended changes
4. **Test loading**: Verify skills still load properly after fixes

## Common Locations
- **Overview sections**: Often duplicated when copying from other skills
- **"When to Use" sections**: Frequently copy-pasted between similar skills  
- **Setup instructions**: Repeated steps appearing in multiple places
- **Header structure**: Duplicate section titles from template reuse

This serves as a reference for future quality review sessions to quickly identify and fix duplication patterns.