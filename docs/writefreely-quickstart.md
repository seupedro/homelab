# WriteFreely Quick Start Guide

## Getting Started in 5 Minutes

### 1. Access Your Site

Visit: **https://write.pane.run**

### 2. Log In

Click "Login" in the top right corner.

**Username**: `seupedro`
**Password**: `changeme123`

⚠️ **IMPORTANT**: Change this password immediately after logging in!

### 3. Change Your Password

1. After logging in, click your username in the top right
2. Go to "Settings" → "Account"
3. Enter a new secure password
4. Click "Update Password"

### 4. Set Up Your Blog

1. Go to "Settings" → "Customize"
2. Update your blog title and description
3. Choose a theme (write, code, forest, or sans)
4. Customize colors and fonts if desired
5. Click "Save changes"

### 5. Write Your First Post

1. Click "New Post" or go to https://write.pane.run/new
2. Write your post in Markdown or plain text
3. Add a title (optional)
4. Click "Publish" when ready

### 6. Create Invite Codes (for inviting users)

1. Go to "Settings" → "Invites"
2. Click "Generate Invite Link"
3. Share the invite code with users you want to invite
4. Users can register at https://write.pane.run with the code

## Common Tasks

### Publishing a Post

```
# Navigate to editor
https://write.pane.run/new

# Write in Markdown
# This is a title

This is **bold** and this is *italic*.

- List item 1
- List item 2

[Link text](https://example.com)

# Click "Publish"
```

### Managing Posts

- **All Posts**: Click your username → "Posts"
- **Edit**: Click on post → Click edit icon
- **Delete**: Click on post → Click delete icon
- **Move to another blog**: Edit post → Change blog from dropdown

### Creating Multiple Blogs

WriteFreely allows each user to have up to 5 blogs:

1. Click your username → "Blogs"
2. Click "New blog"
3. Enter blog alias (URL-friendly name)
4. Enter blog title
5. Click "Create"

Your blogs will be at:
- `https://write.pane.run/<blog-alias>/`

### Customizing Blog Appearance

#### Custom CSS

1. Go to "Settings" → "Customize"
2. Scroll to "Custom CSS"
3. Add your CSS:
   ```css
   body {
       font-family: 'Georgia', serif;
   }

   h1, h2, h3 {
       color: #2c3e50;
   }
   ```
4. Save changes

#### Custom Header/Footer

1. Settings → "Customize"
2. Add HTML in "Header" or "Footer" sections
3. Can include navigation, social links, etc.

### Using Markdown

WriteFreely supports standard Markdown:

```markdown
# Heading 1
## Heading 2
### Heading 3

**bold text**
*italic text*
~~strikethrough~~

- Unordered list
- Item 2

1. Ordered list
2. Item 2

[Link](https://example.com)
![Image](https://example.com/image.jpg)

> Blockquote

`inline code`

\`\`\`
code block
\`\`\`
```

## User Management for Admins

### Creating New Users

**Method 1: Invite Codes (Recommended)**

1. Settings → Invites
2. Generate invite link
3. Share with user
4. User registers with code

**Method 2: CLI (Direct)**

```bash
kubectl exec -n writefreely deployment/writefreely -- /bin/sh -c \
  "cd /go && /go/cmd/writefreely/writefreely --create-admin username:password"
```

### Viewing All Users

```bash
kubectl exec -n writefreely deployment/writefreely -- /bin/sh -c \
  "sqlite3 /data/writefreely.db 'SELECT username, created FROM users;'"
```

## Tips and Tricks

### 1. Use the Pad Editor for Long-Form Writing

Settings → Customize → Editor → Select "Pad"

This gives you a distraction-free writing interface.

### 2. Schedule Posts (via Save as Draft)

1. Write your post
2. Instead of "Publish", save as draft
3. Come back later to publish

### 3. Cross-Post to Multiple Blogs

1. Write post on one blog
2. Copy the content
3. Create new post on another blog
4. Paste and publish

### 4. Use Tags for Organization

Add tags to your posts:
```
#tag1 #tag2 #technology
```

Tags appear at the bottom of posts and can be used for filtering.

### 5. Make Posts Anonymous

- Posts without a blog are anonymous (listed under "Anonymous" section)
- Can be useful for sharing without attribution

### 6. Share Draft Links

Before publishing, you can share a draft link:
1. Write post but don't publish
2. Share the URL (it's already accessible)
3. Publish when ready

## Keyboard Shortcuts

When writing:
- `Ctrl/Cmd + Enter` - Publish post
- `Ctrl/Cmd + S` - Save draft
- `Ctrl/Cmd + B` - Bold
- `Ctrl/Cmd + I` - Italic

## Troubleshooting

### Can't Log In

1. Check username (case-sensitive)
2. Check password
3. Try resetting password via CLI (see main docs)

### Post Not Showing Up

1. Check if published (not draft)
2. Check which blog it's published to
3. Check if blog is public or private

### Images Not Loading

- WriteFreely doesn't host images
- Use external image hosting (Imgur, Cloudinary, etc.)
- Link images in Markdown: `![alt](https://example.com/image.jpg)`

### Invite Code Not Working

1. Check if code was already used (single-use)
2. Generate a new code
3. Make sure user is using exact code

## Advanced Features

### Custom Domain (Future)

To use a custom domain like `blog.example.com`:

1. Point DNS CNAME to `write.pane.run`
2. Update WriteFreely config to allow the domain
3. Restart deployment
4. Certificate will be auto-issued

### Federation / Fediverse (Optional)

To enable ActivityPub federation:

1. Edit `k8s/apps/writefreely/configmap.yaml`
2. Set `federation = true`
3. Apply: `kubectl apply -f k8s/apps/writefreely/configmap.yaml`
4. Restart: `kubectl rollout restart deployment/writefreely -n writefreely`

Users will be discoverable at `@username@write.pane.run` on Mastodon and other ActivityPub platforms.

### Export Data

WriteFreely supports export in various formats:

1. Go to Settings → "Export"
2. Choose format (Plain text, Markdown, HTML, etc.)
3. Download your data

### Import from Other Platforms

Import posts from:
- Medium
- WordPress
- Tumblr

1. Settings → "Import"
2. Upload exported file
3. Posts will be imported to your blog

## Best Practices

1. **Regular Backups**: Admins should run backups regularly
   ```bash
   ~/homelab/scripts/backup-writefreely.sh
   ```

2. **Strong Passwords**: Use unique, strong passwords

3. **Invite Carefully**: Only invite trusted users (invite-only mode)

4. **Monitor Disk Usage**: Check database size periodically
   ```bash
   kubectl exec -n writefreely deployment/writefreely -- du -sh /data/writefreely.db
   ```

5. **Keep Updated**: Update WriteFreely image regularly for security

## Getting Help

- **Full Documentation**: `~/homelab/docs/writefreely.md`
- **Official Docs**: https://writefreely.org/docs
- **Community Forum**: https://discuss.write.as
- **GitHub**: https://github.com/writefreely/writefreely

## Quick Reference Commands

```bash
# View logs
kubectl logs -n writefreely deployment/writefreely -f

# Restart
kubectl rollout restart deployment/writefreely -n writefreely

# Create user
kubectl exec -n writefreely deployment/writefreely -- /bin/sh -c \
  "cd /go && /go/cmd/writefreely/writefreely --create-admin user:pass"

# Backup
~/homelab/scripts/backup-writefreely.sh

# Check status
kubectl get all -n writefreely
```

---

**Quick Links**:
- Site: https://write.pane.run
- Login: https://write.pane.run/login
- New Post: https://write.pane.run/new
- Stats: https://write.pane.run/stats

**Need More Help?** See the full documentation at `~/homelab/docs/writefreely.md`
