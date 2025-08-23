// Font Usage Examples for Campus Crush App
// This file shows how to use the new font system

import 'package:flutter/material.dart';
import 'app_fonts.dart';

class FontUsageExamples extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Font Examples', style: AppFonts.headlineLarge),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Main headings - Use NudMotoya
            Text('Main Heading', style: AppFonts.displayLarge),
            Text('Section Heading', style: AppFonts.headlineLarge),
            Text('Card Title', style: AppFonts.titleLarge),
            
            const SizedBox(height: 20),
            
            // Body text - Use Satoshi-like fonts
            Text('This is body text that should use Satoshi-like fonts for better readability.', 
                 style: AppFonts.bodyLarge),
            Text('Medium body text for general content.', 
                 style: AppFonts.bodyMedium),
            Text('Small body text for captions and details.', 
                 style: AppFonts.bodySmall),
            
            const SizedBox(height: 20),
            
            // Labels and buttons - Use Satoshi-like fonts
            Text('Button Text', style: AppFonts.buttonText),
            Text('Label Text', style: AppFonts.labelMedium),
            Text('Caption Text', style: AppFonts.caption),
            
            const SizedBox(height: 20),
            
            // Custom fonts with specific properties
            Text('Custom Heading', 
                 style: AppFonts.heading(
                   fontSize: 28,
                   fontWeight: FontWeight.w700,
                   color: Colors.purple,
                 )),
            
            Text('Custom Body Text', 
                 style: AppFonts.body(
                   fontSize: 18,
                   fontWeight: FontWeight.w500,
                   color: Colors.grey[600],
                 )),
          ],
        ),
      ),
    );
  }
}

// Quick reference for common use cases:

// 1. App Bar Titles - Use NudMotoya
// AppBar(
//   title: Text('Screen Title', style: AppFonts.headlineLarge),
// )

// 2. Section Headers - Use NudMotoya
// Text('Section Name', style: AppFonts.titleLarge)

// 3. Card Titles - Use NudMotoya
// Text('Card Title', style: AppFonts.titleMedium)

// 4. Body Content - Use Satoshi-like fonts
// Text('Main content text', style: AppFonts.bodyMedium)

// 5. Button Text - Use Satoshi-like fonts
// ElevatedButton(
//   child: Text('Button', style: AppFonts.buttonText),
//   onPressed: () {},
// )

// 6. Form Labels - Use Satoshi-like fonts
// TextFormField(
//   decoration: InputDecoration(
//     labelText: 'Label',
//     labelStyle: AppFonts.bodyMedium,
//   ),
// )

// 7. Captions and Small Text - Use Satoshi-like fonts
// Text('Small text', style: AppFonts.caption)
