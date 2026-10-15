import 'package:flutter/material.dart';

/// A standardized dropdown widget used in registration and profile completion forms.
class RegistrationDropdownField extends StatelessWidget {
  final String label;         // The question or title for the field.
  final String? value;        // The currently selected value.
  final List<String> items;   // The list of options to display.
  final Function(String?) onChanged; // Callback for when a selection is made.
  final String? hint;         // Placeholder text.
  final bool isRequired;      // If true, shows a red asterisk and enforces validation.

  const RegistrationDropdownField({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.hint,
    this.isRequired = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label with an optional red asterisk for mandatory fields.
        RichText(
          text: TextSpan(
            text: label,
            style: const TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold),
            children: isRequired
                ? [const TextSpan(text: ' *', style: TextStyle(color: Colors.red))]
                : [],
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: value,
          hint: hint != null ? Text(hint!) : null,
          isExpanded: true, // Ensures the dropdown fills the available width.
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.grey.shade100,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
          ),
          items: items.map((item) {
            return DropdownMenuItem(
              value: item,
              child: Text(item),
            );
          }).toList(),
          onChanged: onChanged,
          validator: (val) => (isRequired && (val == null || val.isEmpty)) ? 'Required' : null,
        ),
      ],
    );
  }
}

/// A specialized text field that opens a date picker when tapped.
class RegistrationDateField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? hint;
  final VoidCallback onTap;
  final bool isRequired;
  final bool isDisabled; // Used to freeze the field if "don't remember date" is checked.

  const RegistrationDateField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    required this.onTap,
    this.isRequired = true,
    this.isDisabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          readOnly: true, // Prevents manual typing; forcing the use of the date picker.
          onTap: isDisabled ? null : onTap,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: Colors.grey.shade100,
            suffixIcon: const Icon(Icons.calendar_today, size: 20),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
          ),
          validator: (val) {
            // Validation logic: only require a value if the field is active.
            if (isRequired && !isDisabled && (val == null || val.isEmpty)) {
              return 'Required';
            }
            return null;
          },
        ),
      ],
    );
  }
}
