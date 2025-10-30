# Athena Build Instructions

## ⚠️ ONE-TIME SETUP REQUIRED

The project is almost ready to build, but you need to add the **GRDB.swift** package dependency in Xcode.

---

## 🔧 Step-by-Step: Add GRDB Package

### Visual Guide:

1. **Xcode should already be open** with the Athena project

2. **Select the Project** (top-left, blue icon named "Athena")

3. **Select the Target**:
   - In the main area, you'll see "PROJECT" and "TARGETS"
   - Click on **"Athena"** under TARGETS (not the project)

4. **Go to General Tab**:
   - Make sure you're on the "General" tab at the top

5. **Scroll to Frameworks Section**:
   - Scroll down to find "Frameworks, Libraries, and Embedded Content"

6. **Add Package**:
   - Click the **"+"** button (looks like a plus sign)
   - From the dropdown, select **"Add Package Dependency..."**
   
7. **Enter Package URL**:
   - In the search box that appears, paste:
   ```
   https://github.com/groue/GRDB.swift.git
   ```
   - Press Enter or click outside the text field

8. **Wait for Package to Load**:
   - Xcode will fetch the package (may take 10-30 seconds)
   
9. **Select Package Version**:
   - When it appears, it should default to "Up to Next Major Version: 6.0.0 < 7.0.0"
   - This is correct - click **"Add Package"**

10. **Choose Products**:
    - A dialog will show "Package Products"
    - Make sure **"GRDB"** is checked (should be by default)
    - Click **"Add Package"**

11. **Verify Installation**:
    - In the Project Navigator (left sidebar)
    - You should now see "Package Dependencies" section
    - GRDB should be listed there

---

## ✅ Build the Project

Once GRDB is added:

1. **Clean Build Folder**: Press **⌘⇧K** (Command + Shift + K)
2. **Build**: Press **⌘B** (Command + B)
3. **Run**: Press **⌘R** (Command + R)

---

## 🎯 Expected Result

- ✅ Build should succeed with no errors
- ✅ Athena app should launch as a floating window
- ✅ You'll see the welcome screen
- ✅ Click the gear icon to configure API keys

---

## 🐛 If Build Still Fails

If you see other errors after adding GRDB:

1. **Clean Derived Data**:
   ```bash
   rm -rf ~/Library/Developer/Xcode/DerivedData/Athena-*
   ```

2. **Restart Xcode**:
   - Close Xcode completely
   - Reopen the project

3. **Check Swift Version**:
   - Xcode → Settings → Locations → Command Line Tools
   - Make sure it's set to your current Xcode version

4. **Report the Error**:
   - Copy the full error message
   - I'll help fix it!

---

## 📝 Alternative: Command Line (If you prefer)

If you're comfortable with editing pbxproj files manually, here's what needs to be added:

**NOT RECOMMENDED** - Very error-prone. Use Xcode GUI instead.

---

## 🚀 Next Steps After Successful Build

1. **Start Python Backend**:
   ```bash
   cd Backend
   python3 -m venv venv
   source venv/bin/activate
   pip install -r requirements.txt
   python main.py
   ```

2. **Run Athena**:
   - Should already be running from Xcode
   - Click Settings (gear icon)
   - Add your OpenAI and/or Anthropic API keys
   - Start chatting!

---

## 💡 Why This Manual Step?

Swift Package Manager dependencies in Xcode projects must be added through Xcode's GUI or by complex binary file manipulation. This is a one-time setup - once GRDB is added, it's saved in your project and you won't need to do this again.

---

**Ready? Let's add that package! It takes less than 2 minutes.** ⏱️

