//
//  OrdersViewController.swift
//  HajdeHajm
//
//  Created by Kujtim Saliu on 17.10.24.
//

import UIKit
import FirebaseFirestore
import FirebaseAuth

class OrdersViewController: UIViewController {
    
    // MARK: - Properties
    private var menuItems: [MenuItem] = []
    private var selectedItems: [MenuItem: Int] = [:]
    
    // MARK: - UI Components
    private let tableView: UITableView = {
        let tv = UITableView()
        tv.register(MenuItemCell.self, forCellReuseIdentifier: "MenuItemCell")
        return tv
    }()
    
    private let totalLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        label.textAlignment = .right
        return label
    }()
    
    private let submitButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Submit Order", for: .normal)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 8
        return button
    }()
    
    // MARK: - Lifecycle Methods
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        fetchMenuItems()
    }
    
    // MARK: - Setup Methods
    private func setupUI() {
        title = "Menu"
        view.backgroundColor = .systemBackground
        
        view.addSubview(tableView)
        view.addSubview(totalLabel)
        view.addSubview(submitButton)
        
        tableView.translatesAutoresizingMaskIntoConstraints = false
        totalLabel.translatesAutoresizingMaskIntoConstraints = false
        submitButton.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: totalLabel.topAnchor, constant: -20),
            
            totalLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            totalLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            totalLabel.bottomAnchor.constraint(equalTo: submitButton.topAnchor, constant: -20),
            
            submitButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            submitButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            submitButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            submitButton.heightAnchor.constraint(equalToConstant: 50)
        ])
        
        tableView.delegate = self
        tableView.dataSource = self
        
        submitButton.addTarget(self, action: #selector(submitOrder), for: .touchUpInside)
    }
    
    private func fetchMenuItems() {
        FirestoreManager.shared.fetchMenuItems { [weak self] result in
            switch result {
            case .success(let items):
                self?.menuItems = items
                DispatchQueue.main.async {
                    self?.tableView.reloadData()
                }
            case .failure(let error):
                print("Error fetching menu items: \(error.localizedDescription)")
                // Handle error (e.g., show an alert to the user)
            }
        }
    }
    
    @objc private func submitOrder() {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("User not logged in")
            // Show an alert to the user that they need to log in
            let alert = UIAlertController(title: "Not Logged In", message: "Please log in to submit an order.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            present(alert, animated: true, completion: nil)
            return
        }
        
        let order = Order(userId: userId, items: selectedItems, date: Date())
        
        FirestoreManager.shared.saveOrder(order) { [weak self] result in
            switch result {
            case .success:
                DispatchQueue.main.async {
                    self?.showOrderConfirmation()
                    self?.clearOrder()
                }
            case .failure(let error):
                print("Error saving order: \(error.localizedDescription)")
                // Handle error (e.g., show an alert to the user)
                DispatchQueue.main.async {
                    let alert = UIAlertController(title: "Order Submission Failed", message: "There was an error submitting your order. Please try again.", preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                    self?.present(alert, animated: true, completion: nil)
                }
            }
        }
    }
    
    
    private func showOrderConfirmation() {
        let alert = UIAlertController(title: "Order Submitted", message: "Your order has been successfully submitted.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        present(alert, animated: true, completion: nil)
    }
    
    private func clearOrder() {
        selectedItems.removeAll()
        tableView.reloadData()
        updateTotalLabel()
    }
    
    private func updateTotalLabel() {
        let total = selectedItems.reduce(0) { $0 + ($1.key.price * $1.value) }
        totalLabel.text = "Total: \(total) MKD"
        
        if total > 150 {
            let excess = total - 150
            totalLabel.text?.append(" (You pay: \(excess) MKD)")
        }
        
        submitButton.isEnabled = !selectedItems.isEmpty
    }
    
    //    @objc private func submitOrder() {
    //        let order = Order(userId: "1", items: selectedItems, date: Date())
    //        // In a real app, you would save this order to Firestore
    //        print("Order submitted: \(order)")
    //
    //        // Clear the selected items and update the UI
    //        selectedItems.removeAll()
    //        tableView.reloadData()
    //        updateTotalLabel()
    //
    //        // Show a confirmation to the user
    //        let alert = UIAlertController(title: "Order Submitted", message: "Your order has been successfully submitted.", preferredStyle: .alert)
    //        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
    //        present(alert, animated: true, completion: nil)
    //    }
}

// MARK: - UITableViewDelegate, UITableViewDataSource
extension OrdersViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return menuItems.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "MenuItemCell", for: indexPath) as! MenuItemCell
        let menuItem = menuItems[indexPath.row]
        cell.configure(with: menuItem, quantity: selectedItems[menuItem] ?? 0)
        cell.delegate = self
        return cell
    }
}

// MARK: - MenuItemCellDelegate
extension OrdersViewController: MenuItemCellDelegate {
    func cell(_ cell: MenuItemCell, didUpdateQuantityFor menuItem: MenuItem, to quantity: Int) {
        if quantity > 0 {
            selectedItems[menuItem] = quantity
        } else {
            selectedItems.removeValue(forKey: menuItem)
        }
        updateTotalLabel()
    }
}