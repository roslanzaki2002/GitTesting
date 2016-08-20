# Git useful commands


## Configuration

### Initial

  ```
  git config --global user.name "Roslan Zaki"
  git config --global user.email "rzaki@juniper.net" 

  ```


## Branching 

### Create a branch __roslan_test__

   ```
   git branch roslan_test

   ```

### Use the new branch __roslan_test__

   ```
   git checkout roslan_test

   ```

### Delete branch __roslan_test__ on remote server

  ```
  git push origin --delete roslan_test

  ```

### Delete local copy of __roslan_test__

  ```
  git branch -d roslan_test
  
  ```
