import { useState } from 'react';
import {
  Button,
  Linking,
  Pressable,
  SafeAreaView,
  StyleSheet,
  Text,
  TextInput,
} from 'react-native';

import { signIn } from './auth';

const PRIVACY_POLICY_URL = '__PRIVACY_POLICY_URL__';

type Props = { onSignedIn: (sessionToken: string) => void };

export default function LoginScreen({ onSignedIn }: Props) {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');

  async function submit() {
    setError('');
    try {
      onSignedIn(await signIn(email.trim(), password));
    } catch {
      setError('Wrong email or password.');
    }
  }

  return (
    <SafeAreaView style={styles.container}>
      <Text style={styles.title}>Sign in</Text>
      <Text style={styles.hint}>Use the account your team gave you.</Text>
      <TextInput
        style={styles.input}
        value={email}
        onChangeText={setEmail}
        placeholder="Email"
        autoCapitalize="none"
        keyboardType="email-address"
      />
      <TextInput
        style={styles.input}
        value={password}
        onChangeText={setPassword}
        placeholder="Password"
        secureTextEntry
      />
      {error ? <Text style={styles.error}>{error}</Text> : null}
      <Button title="Sign in" onPress={submit} />
      <Pressable onPress={() => Linking.openURL(PRIVACY_POLICY_URL)}>
        <Text style={styles.link}>Privacy policy</Text>
      </Pressable>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#fff', padding: 24, paddingTop: 64, gap: 12 },
  title: { fontSize: 28, fontWeight: '600' },
  hint: { color: '#555' },
  input: { borderWidth: 1, borderColor: '#ccc', borderRadius: 6, padding: 8 },
  error: { color: '#b00020' },
  link: { color: '#06c', paddingVertical: 8 },
});
