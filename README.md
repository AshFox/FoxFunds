# FoxFunds

FoxFunds is a personal finance management app built with Flutter. It helps users track their income, expenses, savings goals ("jars"), and set budgets for better financial control.

## Features
- Add, edit, and delete transactions (income & expenses)
- Categorize transactions (e.g., rent, groceries, salary, etc.)
- Set and manage savings goals using "jars"
- Set weekly or monthly budgets (overall or per category)
- View financial summaries and transaction history
- Persistent local storage using SQLite
- Modern, intuitive UI

## Getting Started

### Prerequisites
- [Flutter SDK](https://flutter.dev/docs/get-started/install)
- Android Studio or Xcode (for emulator/simulator or device deployment)

### Installation
1. **Clone the repository:**
   ```bash
   git clone <your-repo-url>
   cd FoxF
   ```
2. **Install dependencies:**
   ```bash
   flutter pub get
   ```
3. **Run the app:**
   ```bash
   flutter run
   ```

## Project Structure
- `lib/` - Main Dart codebase
  - `models/` - Data models (Budget, Category, Jar, Transaction)
  - `screens/` - App screens (Home, Jars, Summary, Settings, etc.)
  - `services/` - Database and business logic
  - `widgets/` - Reusable UI components
  - `themes/` - App theming
- `android/` - Android native code
- `test/` - Widget and unit tests

## Usage
- **Add Transactions:** Use the "+" button to add income or expense.
- **Manage Jars:** Create savings goals and allocate funds.
- **Set Budgets:** Tap the edit icon on the home screen to set or update your budget.
- **View Summary:** See your spending and saving trends on the summary page.

## Contributing
Contributions are welcome! Please open issues or submit pull requests for improvements and bug fixes.

## License
This project is licensed under the MIT License.
